# compare_glober_mall.pl
# author:T.Haashiguchi
# date:2014/5/1

#========== 改訂履歴 ==========
# date:2014/05/01 modify
# ・genre_goods.csvの読み込み処理削除
#  -特にどこでも使用されていない為sabunファイルへの出力中止
#-----

########################################################
## Glober(本店)とHFF(楽天店)の商品の差分を抽出するプログラム  
## です。抽出には以下のファイルを入力として使用します。
## 【入力ファイル】
## ・goods.csv                                         
##    -本店の管理をしているECBeingからダウンロードしたアイテムリストファイル                        
## ・dl-itemYYYYMMDDHHMM-X.csv
## ・dl-selectYYYYMMDDHHMM-X.csv
##    -楽天管理システムからダウンロードしたファイル
## ・cut_goods_code.csv
##    -差分ファイルから除外する商品コード一覧
## 【出力ファイル】
## ・sabun_YYYYMMDD.csv
##   -本店とモール店の差分商品
##  　　 -商品番号
##   　　-商品ブランド
##   　　-商品名
##   　　-在庫数
##   　　-コントロールカラム
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use XML::Simple;
use Encode;
use Text::CSV_XS;

# ログファイルを格納するフォルダ名
my $output_log_dir="./../log";
# ログフォルダが存在しない場合は作成
unless (-d $output_log_dir) {
    mkdir $output_log_dir or die "ERROR!! create $output_log_dir failed";
}
#　ログファイル名
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
my $time_str = sprintf("%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $log_file_name="$output_log_dir"."/"."compare_glober_mall"."$time_str".".log";
# ログファイルのオープン
open(LOG_FILE, "> $log_file_name") or die("ERROR!! $log_file_name open failed.");
# 出力ファイルを格納するフォルダ名
my $output_dir="./..";
# 出力ファイル名
my $date_str = sprintf("%04d%02d%02d" ,$year + 1900, $mon + 1, $mday);
my $sabun_file_name="$output_dir"."/"."sabun_"."$date_str".".csv";
# 入力ファイル格納フォルダのオープン
my $input_dir=Cwd::getcwd();
$input_dir="$input_dir"."/..";
opendir(INPUT_DIR, "$input_dir") or die("ERROR!! $input_dir failed.");
#　入力ファイル格納フォルダ内のファイル名をチェック
my $category_xml_filename="./xml/category.xml";
my $goods_file_name="goods.csv";
my $goods_file_find=0;
my $dl_item_file_name="";
my $dl_item_file_find=0;
my $dl_item_file_multi=0;
my $dl_select_file_name="";
my $dl_select_file_find=0;
my $dl_select_file_multi=0;
my $cut_goods_code_file_name="cut_goods_code.csv";
my $input_dir_file_name;
while ($input_dir_file_name = readdir(INPUT_DIR)){
	if($input_dir_file_name eq $goods_file_name) {
		$goods_file_find=1;
		next;
	}
	elsif(index($input_dir_file_name, "dl-item", 0) != -1) {
		if ($dl_item_file_find) {
			#dl-itemYYYYMMDDファイルが複数存在する
			$dl_item_file_multi=1;
			next;
		}
		else {
			$dl_item_file_find=1;
			$dl_item_file_name=$input_dir_file_name;
			next;
		}
	}
	elsif(index($input_dir_file_name, "dl-select", 0) != -1) {
		if ($dl_select_file_find) {
			#dl-itemYYYYMMDDファイルが複数存在する
			$dl_select_file_multi=1;
			next;
		}
		else {
			$dl_select_file_find=1;
			$dl_select_file_name=$input_dir_file_name;
			next;
		}
	}
}
closedir(INPUT_DIR);
if (!$goods_file_find) {
	#goods.csvファイルが存在しない
	output_log("ERROR!! Not exist $goods_file_name.\n");
}
if (!$dl_item_file_find) {
	#dl-itemyyyymmdd.csvファイルが存在しない
	print("ERROR!! Not exist dl-itemyyyymmdd.csv.\n");
}
if ($dl_item_file_multi) {
	#dl-itemyyyymmdd.csvファイルが複数存在する
	output_log("ERROR!! dl-itemyyyymmdd.csv　is exist over 2.\n");
}
if (!$dl_select_file_find) {
	#dl-selectyyyymmdd.csvファイルが存在しない
	print("ERROR!! Not exist dl-selectyyyymmdd.csv.\n");
}
if ($dl_select_file_multi) {
	#dl-selectyyyymmdd.csvファイルが複数存在する
	output_log("ERROR!! dl-selectyyyymmdd.csv　is exist over 2.\n");
}
if (!$goods_file_find || !$dl_item_file_find || $dl_item_file_multi || !$dl_select_file_find || $dl_select_file_multi) {
	#入力ファイルが不正
	exit 1;
}

# 入力ファイルのオープン
$goods_file_name = "$input_dir"."/"."$goods_file_name";
if (!open(GOODS_FILE, "< $goods_file_name")) {
	output_log("ERROR!!($!) $goods_file_name open failed.\n");
	exit 1;
}

my $is_exist_cut_goods_code_file=0;
$cut_goods_code_file_name = "$input_dir"."/"."$cut_goods_code_file_name";
if(-e $cut_goods_code_file_name) {
	#ファイルが存在すれば読み込む
	if (!open(CUT_GOODS_CODE_FILE, "< $cut_goods_code_file_name")) {
		output_log("ERROR!!($!) $cut_goods_code_file_name open failed.\n");
		exit 1;
	}
	$is_exist_cut_goods_code_file=1;
}
$dl_item_file_name = "$input_dir"."/"."$dl_item_file_name";
if (!open(ITEM_FILE, "< $dl_item_file_name")) {
	output_log("ERROR!!($!) $dl_item_file_name open failed.\n");
	exit 1;
}
$dl_select_file_name = "$input_dir"."/"."$dl_select_file_name";
if (!open(SELECT_FILE, "< $dl_select_file_name")) {
	output_log("ERROR!!($!) $dl_select_file_name open failed.\n");
	exit 1;
}
# 出力ファイルのオープン
my $output_sabun_csv = Text::CSV_XS->new({ binary => 1 });
if (!open(SABUN_FILE, "> $sabun_file_name")) {
	output_log("ERROR!!($!) $sabun_file_name open failed.");
	exit 1;
}

# 処理開始
output_log("**********START**********\n");

# CSV項目の出力
my @csv_item_name=("商品コード","カテゴリ名","商品名","販売価格","サイズ","カラー","在庫数","コントロームカラム","親の画像枚数","バリエーション","楽天用ファイル名","Yahoo用ファイル名");
my $csv_item_name_num=@csv_item_name;
my $csv_item_name_count=0;
for my $csv_item_name_str (@csv_item_name) {
	Encode::from_to( $csv_item_name_str, 'utf8', 'shiftjis' );
	$output_sabun_csv->combine($csv_item_name_str) or die $output_sabun_csv->error_diag();
	my $post_fix_str="";
	if (++$csv_item_name_count >= $csv_item_name_num) {
		$post_fix_str="\n";
	}
	else {
		$post_fix_str=",";
	}
	print SABUN_FILE $output_sabun_csv->string(), $post_fix_str;
}

# 本店データの商品コードを配列に読み出す
my @tmp_glober_goods_code="";
my $goods_line = <GOODS_FILE>;
while($goods_line = <GOODS_FILE>){
	my @glober_goods=split(/,/, $goods_line);
	push(@tmp_glober_goods_code, $glober_goods[0]);
}

seek(GOODS_FILE, 0, 0);
$goods_line = <GOODS_FILE>;
while($goods_line = <GOODS_FILE>){
	# 本店の商品コード抽出
	my @glober_goods=split(/,/, $goods_line);
	my $glober_goods_9code=$glober_goods[0];
	my $glober_goods_5code=get_5code($glober_goods_9code);
	my $find_flag=0;
	my $find_duplication_flag=0;
	my $colmn="n";
	if ($is_exist_cut_goods_code_file) {
		# 除外ファイルの読み出し
		seek(CUT_GOODS_CODE_FILE,0,0);
		while(my $cut_goods_code_line = <CUT_GOODS_CODE_FILE>){	
			# 除外ファイルと比較
			my @rakuten_cut_code=split(/,/, $cut_goods_code_line);
			my $rakuten_cut_code=$rakuten_cut_code[0];
			if ($rakuten_cut_code==$glober_goods_9code) {
				#除外リストに合致した場合はflagを立てる
				$find_flag=1;
				last;
			}
		}
		if($find_flag) {
			next;
		}
	}
	# 9桁コードとの合致判定
	seek(ITEM_FILE,0,0);
	# 1行目は読み飛ばす
	my $item_line = <ITEM_FILE>;
	while($item_line = <ITEM_FILE>){	
		# itemファイルの9桁コードと比較
		my @rakuten_item=split(/,/, $item_line);
		# 9桁コードか否かのチェック
		my $rakuten_item_code=$rakuten_item[2];
		if(is_9code($rakuten_item_code)) {
			# 9桁との比較処理
			if ($glober_goods_9code == $rakuten_item_code) {
				$find_flag=1;
				my $goods_code_itr=1;
				my $temp_find_flag=0;
				while(my $comp_glober_goods_code = $tmp_glober_goods_code[$goods_code_itr++]){
					if (get_5code($comp_glober_goods_code) == get_5code($glober_goods_9code)) {
						if($temp_find_flag) {
							$find_duplication_flag=1;
							$find_flag=0;
							last;
						}
						else {
							$temp_find_flag=1;
						}
					} 
				}
				last;

			}					
		}
		else {
			#5桁の比較処理
			if (get_5code($glober_goods_9code) == get_5code($rakuten_item_code)) {
				# selectファイルの読み出し
				# 1行目は読み飛ばす	
				my $rakuten_select_code=0;
				seek(SELECT_FILE,0,0);
				my $select_line = <SELECT_FILE>;
				while($select_line = <SELECT_FILE>){	
					# selectファイルの5桁+4桁コードと比較
					my @rakuten_select_code=split(/,/, $select_line);		
					my $rakuten_select_4_code=delete_double_quotation($rakuten_select_code[6]);
					# selectファイルの項目選択肢横軸子番号に4ケタがあるかが確認する。
					# selectファイルの項目選択肢横軸子番号に4ケタがなかったら、項目選択肢縦軸子番号を変数に入れる。
					if (length($rakuten_select_4_code) != 4) {
						$rakuten_select_4_code = delete_double_quotation($rakuten_select_code[8]);
					}
					my $rakuten_select_5code=delete_double_quotation($rakuten_select_code[1]); 
					my $rakuten_select_code="$rakuten_select_5code$rakuten_select_4_code";
					if ($glober_goods_9code eq $rakuten_select_code) {
						$find_flag=1;
						last;
					}
				}
				if ($find_flag) {
					last;
				}
				#更新商品
				$colmn="u";
				last;
			}
		}
	}
	# sabun.csvに値を出力する。
	if (!$find_flag) {
		$output_sabun_csv->combine($glober_goods[0]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[1]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[2]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[3]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[5]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[6]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[7]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($colmn) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), "\n";
	}
	if($find_duplication_flag) {
		# 既に9桁で商品登録されている場合は一度削除する必要があるので、コントロールカラム"d"でも出力
		$output_sabun_csv->combine($glober_goods[0]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[1]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[2]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[3]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[5]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[6]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine($glober_goods[7]) or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("d") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";	
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), ",";
		$output_sabun_csv->combine("") or die $output_sabun_csv->error_diag();
		print SABUN_FILE $output_sabun_csv->string(), "\n";
		
	}
}

$output_sabun_csv->eof;

# ファイルのクローズ			
close(GOODS_FILE);
close(ITEM_FILE);
close(SELECT_FILE);
close(SABUN_FILE);
if ($is_exist_cut_goods_code_file){close(CUT_GOODS_CODE_FILE);}

# 処理終了
output_log("Process is Success!!\n");
output_log("**********END**********\n");

##########################################################################################
##############################  sub routin   #############################################
##########################################################################################
## ログ出力
sub output_log {
	my $day=::to_YYYYMMDD_string();
	print LOG_FILE "[$day]:$_[0]\n";
}

## 現在日時取得関数
sub to_YYYYMMDD_string {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $result = sprintf("%04d%02d%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
  return $result;
}

sub delete_double_quotation {
	my $str = $_[0]; 
	# ""の存在チェック
	my $substr_begin_point=0;
	if (index($str, "\"", 0) != -1) {
		$substr_begin_point=index($str, "\"", 0);	
	}
	my $substr_end_point=length($str);
	if (rindex($str, "\"") != -1) {
		$substr_end_point = rindex($str, "\"");
	}
	return substr($str, $substr_begin_point, $substr_end_point);
}

sub get_5code {
	return substr(delete_double_quotation($_[0]), 0, 5);
}

sub is_9code {
	my $temp=delete_double_quotation($_[0]);
	if (length(delete_double_quotation($_[0])) == 9) {
		return 1;
	}
	else {
		return 0;
	}
}