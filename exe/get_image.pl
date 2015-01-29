# get_image.pl
# author:T.Hashiguchi
# date:2014/5/10
#========== 改訂履歴 ==========
# date:2012/11/1 modify
# ・goods.csvの9桁化に対応
#-----
# date:2012/11/23 modify
# 9枚以上の画像に対応
# ファイル名に"_a","_b","_c"を付与
#-----

########################################################
## 指定された商品コードの画像ファイルをGlober(本店)から取得する。 
## 【入力ファイル】
## ・goods.csv
## ・sabun_YYYYMMDD.csv
## 【出力ファイル】
## ・image_num.csv
##    -取得した画像数を記載
## 【ログファイル】
## ・get_image_yyyymmddhhmmss.log
##    -エラー情報などの処理内容を出力
##
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Image::Magick;
use File::Copy;
use File::Path;
use Archive::Zip;
use lib './lib'; 
use ImgResize;
use IO::Handle;
use Text::CSV_XS;
use XML::Simple;
use Encode;

# ログファイルを格納するフォルダ名
my $output_log_dir="./../log";
# ログフォルダが存在しない場合は作成
unless (-d $output_log_dir) {
    mkdir $output_log_dir or die "ERROR!! create $output_log_dir failed";
}
#　ログファイル名
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
my $time_str = sprintf("%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $log_file_name="$output_log_dir"."/"."get_image"."$time_str".".log";
# ログファイルのオープン
if(!open(LOG_FILE, "> $log_file_name")) {
	print "ERROR!!($!) $log_file_name open failed.\n";
	exit 1;
}
# グローバー画像URL
my $glober_url="http://glober.jp/img/goods";
# 出力ファイルを格納するフォルダ名
my $output_dir="./..";
# 各商品のSKU番号と画像数を格納するファイル名
my $regist_mall_data_file_name="$output_dir"."/"."regist_mall_data_file_temp.csv";
my $regist_mall_data_file_name_correct="$output_dir"."/"."regist_mall_data_file.csv";
# 画像を保存するフォルダ名
my $r_image_dir="../rakuten_up_data/pic";
my $y_image_dir="../yahoo_up_data/yahoo_image";
my $y_s_over6_image_dir="../yahoo_up_data/yahoo_image_s_over6";
# 取得する写真上限枚数(モール店で使用する最大画像数)
my $get_image_max_num_= 50;
# Yahooの画像ZIPファイルに格納するファイル数(上限15MB)
my $y_image_max=140;
my $y_s_over6_image_max=280;
# 画像変換用モジュールの初期化
my $img_resize = new ImgResize(-1);
# ZIP用モジュール
my $y_zip = Archive::Zip->new();
my $y_s_over6_zip = Archive::Zip->new();
# 入力ファイル格納フォルダのオープン
my $input_dir=Cwd::getcwd();
$input_dir="$input_dir"."/..";
opendir(INPUT_DIR, "$input_dir") or die("ERROR!! $input_dir failed.");
#　入力ファイル格納フォルダ内のファイル名をチェック
my $goods_file_name="goods.csv";
my $goods_file_find=0;
my $sabun_file_name="";
my $sabun_file_find=0;
my $sabun_file_multi=0;
my $input_dir_file_name;
while ($input_dir_file_name = readdir(INPUT_DIR)){
	if($input_dir_file_name eq $goods_file_name) {
		$goods_file_find=1;
		next;
	}
	elsif(index($input_dir_file_name, "sabun_", 0) == 0) {
		if ($sabun_file_find) {
			#sabun_YYYYMMDDファイルが複数存在する
			$sabun_file_multi=1;
			next;
		}
		else {
			$sabun_file_find=1;
			$sabun_file_name=$input_dir_file_name;
			next;
		}
	}
}
closedir(INPUT_DIR);
if (!$sabun_file_find) {
	#sabun_YYYYMMDD.csvファイルが存在しない
	&output_log("ERROR!! Not exist sabun_YYYYMMDD.csv.\n");
}
if ($sabun_file_multi) {
	#sabun_YYYYMMDD.csvファイルが複数存在する
	&output_log("ERROR!! sabun_YYYYMMDD.csv is exist over 2.\n");
}
if (!$goods_file_find || !$sabun_file_find || $sabun_file_multi) {
	#入力ファイルが不正
	exit 1;
}

# 入出力ファイルにディレクトリを付加
$goods_file_name = "$input_dir"."/"."$goods_file_name";
$sabun_file_name = "$input_dir"."/"."$sabun_file_name";
# ファイルのオープン
my $input_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_file_disc;
if (!open ($input_goods_file_disc, "<", $goods_file_name)) {
	&output_log("ERROR!!($!) $goods_file_name open failed.");
	exit 1;
}
my $input_sabun_csv = Text::CSV_XS->new({ binary => 1 });
my $input_sabun_file_disc;
if (!open ($input_sabun_file_disc, "<", $sabun_file_name)) {
	&output_log("ERROR!!($!) $sabun_file_name open failed.");
	exit 1;
}
my $output_regist_mall_data_csv = Text::CSV_XS->new({ binary => 1 });
my $output_regist_mall_data_file_disc;

my $output_regist_mall_data_csv_correct = Text::CSV_XS->new({ binary => 1 });
my $output_regist_mall_data_file_disc_correct;

my $input_regist_mall_data_csv = Text::CSV_XS->new({ binary => 1 });
my $input_regist_mall_data_file_disc;


####################
##　参照ファイルの存在チェック
####################
my $brand_xml_filename="brand.xml";
#参照ファイル配置ディレクトリのオープン
my $current_dir=Cwd::getcwd();
my $ref_dir ="$current_dir"."/xml";
if (!opendir(REF_DIR, "$ref_dir")) {
	&output_log("ERROR!!($!) $ref_dir open failed.");
	exit 1;
}
#　参照ファイルの有無チェック
my $brand_xml_file_find=0;
while (my $ref_dir_file_name = readdir(REF_DIR)){
	if($ref_dir_file_name eq $brand_xml_filename) {
		$brand_xml_file_find=1;
		last;
	}
}
closedir(REF_DIR);
if (!$brand_xml_file_find) {
	#brand.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $brand_xml_filename.\n");
	exit;
}

$brand_xml_filename="$ref_dir"."/"."$brand_xml_filename";

# 画像を保存するフォルダを作成
if(-d $r_image_dir) {
	# 既に存在している場合は削除
	rmtree($r_image_dir, {verbose => 1});
}
mkpath($r_image_dir) or die("ERROR!! $r_image_dir create failed.");
if(-d $y_image_dir) {
	# 既に存在している場合は削除
	rmtree($y_image_dir, {verbose => 1});
}
mkpath($y_image_dir) or die("ERROR!! $y_image_dir create failed.");
if(-d $y_s_over6_image_dir) {
	# 既に存在している場合は削除
	rmtree($y_s_over6_image_dir, {verbose => 1});
}
mkpath($y_s_over6_image_dir) or die("ERROR!! $y_s_over6_image_dir create failed.");

# ヤフー用zipファイルに格納するファイル数
my $y_zip_count=0;
my $y_s_over6_zip_count=0;

# 処理開始
&output_log("*************************\n");
&output_log("**********START**********\n");
&output_log("*************************\n");
# sabun.csvを1行ずつ読み込み7桁の取得リストを作成する。
my %target_image_num;
my %target_variation;
my @code_7_list=();
# _6未満の画像のリスト
my @y_img_list = ();
# _6以上の画像のリスト
my @y_6over_img_list = ();
my $sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){
	# 既に処理済みの商品の場合はスキップ
	my $skip_flag=0;
	while ( my ($code_9, $image_cnt) = each %target_image_num ) {	
		if (@$sabun_line[0] == $code_9) {
			$skip_flag=1;
			last;
		}
	}
	if ($skip_flag) {
		next;
	}
	my @code_7_list_tmp=();
	my $code_9=@$sabun_line[0];
	my $brand_name="";
	seek $input_goods_file_disc, 0, 0;
	# バリエーション商品かどうかの判定
	my $find_5code_count=0;
	my $goods_line = $input_goods_csv->getline($input_goods_file_disc);
	while($goods_line = $input_goods_csv->getline($input_goods_file_disc)){
		# 本店の商品コード抽出
		if (get_5code(@$sabun_line[0]) == get_5code(@$goods_line[0])) {
			$find_5code_count++;
			my $find_flag_tmp=0;
			foreach my $code_7_tmp (@code_7_list) {
				if ($code_7_tmp == get_7code(@$goods_line[0])) {
					$find_flag_tmp=1;
					last;
				}
			}
			# カラーバリエーションの商品を保持する
			if (!$find_flag_tmp) {
				push(@code_7_list_tmp, get_7code(@$goods_line[0]));
				push(@code_7_list, get_7code(@$goods_line[0]));
			}	
			if ($brand_name eq "") {
				$brand_name = get_brandname_from_xml(@$goods_line[1]);
			}
		}
	}
	if ($find_5code_count == 1) {
		# goods.csvに5桁が合致する商品が一つしかなかったのでバリエーション商品ではない
		$target_variation{$code_9}=0;
	}
	else {
		# goods.csvに5桁が合致する商品が複数あったのでバリエーション商品
		$target_variation{$code_9}=1;
	}	
	# wgetで楽天用商品画像を取得する
	my $target_code_7;
	my $total_image_cnt=0;
	foreach $target_code_7 (@code_7_list_tmp) {
		# ブランド名が取得できた商品のみ画像取得処理
		if ($brand_name eq "") {
			last;
		}
		my $rtn=0;
		my $cnt=0;
		while(!$rtn) {
			# 画像の最大枚数を越えたら終了。
			$cnt++;
			if ($cnt > $get_image_max_num_) {
					last;
			}
			# 楽天用フォルダに画像を取得
			my $image_file_name="$target_code_7"."_$cnt".".jpg";
			if( -f $r_image_dir."/".$target_code_7."_".$cnt.".jpg" ) {
				# 既に画像取得済みの場合はスキップ
				next;
			}			
			$rtn = system("wget.exe -q -P $r_image_dir $glober_url/$cnt/$image_file_name");
			# 7桁の品番で画像を探して指定のファイルが見つからなかったら、次の7桁の品番$image_codeで探す。
			if($rtn){
				$cnt--;
				last;
			}
			# フォルダ作成
			my $target_dir=$r_image_dir."/".$brand_name."/".$cnt;
			&create_dir($target_dir);
			my $target_cnt = $cnt%8;
			# ブランド毎_n毎のフォルダに格納する。
			copy($r_image_dir."/".$target_code_7."_".$cnt.".jpg", $target_dir."/".$target_code_7."_".get_target_image_prefix($cnt).$cnt.".jpg") or die ("ERROR!!".$r_image_dir."\\".$target_code_7."_".$cnt.".jpg"." copy failed.");
			&image_resize($target_dir."/".$target_code_7."_".get_target_image_prefix($cnt).$cnt.".jpg", $target_dir."/".$target_code_7."_".get_target_image_prefix($cnt).$cnt."s.jpg", 70, 70, 70);
		}
		$total_image_cnt+=$cnt;
	}
	$target_image_num{$code_9}=$total_image_cnt;

}

# sabunファイルの情報に"親の画像枚数","バリエーション"を追加してregist_mall_data_file.csvを作成
if (!open $output_regist_mall_data_file_disc, ">", $regist_mall_data_file_name) {
	&output_log("ERROR!!($!) $regist_mall_data_file_name open failed.");
	exit 1;
}
seek $input_sabun_file_disc, 0, 0;
$sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
for (my $i=0; $i < 12; $i++) {
	$output_regist_mall_data_csv->combine(@$sabun_line[$i]) or die $output_regist_mall_data_csv->error_diag();
	if ($i == 11) {
		print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), "\n";
	}
	else {
		print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
	}
}
while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){
	for (my $i=0; $i < 8; $i++) {
		$output_regist_mall_data_csv->combine(@$sabun_line[$i]) or die $output_regist_mall_data_csv->error_diag();
		print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
	}
	my $find_flag=0;
	while ( my ($code_9, $image_cnt) = each %target_image_num ) {
		if ($code_9 eq @$sabun_line[0]) {
			$output_regist_mall_data_csv->combine($image_cnt) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine($target_variation{$code_9}) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), "\n";	
			$find_flag=1;
		}
	}
	if (!$find_flag) {
		#sabun.csvに該当する商品が存在しない
		&output_log("ERROR!!($!) critical error.\n");
		exit;
	}
}
close $output_regist_mall_data_file_disc;

if (!open $input_regist_mall_data_file_disc, "<", $regist_mall_data_file_name) {
	&output_log("ERROR!!($!) $regist_mall_data_file_name open failed.");
	exit 1;
}
# ファイル名リストの作成
my @done_list=();
my %y_filename_lists;
my %r_filename_lists;
# 登録対象商品の読み出し
my $regist_mall_data_line = $input_regist_mall_data_csv->getline($input_regist_mall_data_file_disc);
while($regist_mall_data_line = $input_regist_mall_data_csv->getline($input_regist_mall_data_file_disc)){
	my $skip_flag=0;
	#既に処理されているバリエーション商品は処理しない
	foreach my $done_code (@done_list) { 
		if ($done_code == @$regist_mall_data_line[0]) {
			$skip_flag=1;
			last;
		}
	}
	if ($skip_flag) {
		next;
	}
	if (@$regist_mall_data_line[8] == 0) {
		#画像がないので何もしない
		next;
	}
	# 画像リストを取得
	my $wd = Cwd::getcwd();
	chdir $r_image_dir;
	my @tmp_r_jpg_list = glob "*.jpg";
	chdir $wd;
	# リストを昇順で並べる。
	my %jpg_hash=();
	foreach my $r_jpg_name (@tmp_r_jpg_list) {
		my $keynumber = get_keynumber_from_filename($r_jpg_name);
		$jpg_hash{$keynumber} = $r_jpg_name;
	}
	my @r_jpg_list=();
	foreach my $key (sort {$a cmp $b} keys %jpg_hash) {  
		push(@r_jpg_list, $jpg_hash{$key});
	}
	my $y_file_count=0;
	my $y_full_file_name;
	my $y_file_name;
	my $y_thumb_full_file_name;
	my $y_thumb_file_name;
	my $r_filename_list="";
	my $y_filename_list="";
	if (@$regist_mall_data_line[9] == 0) {
		# バリエーションがないので9桁のファイル名
		foreach my $r_jpg_name (@r_jpg_list) {
			my $sub_jpg_name = substr($r_jpg_name, 0, 5);
			if (get_5code(@$regist_mall_data_line[0]) eq $sub_jpg_name) {
				# 登録商品と画像ファイル名の上位5桁が合致したら画像ファイルの番号を確認
				my $sub_jpg_num = substr($r_jpg_name, 8, get_image_numdigit_from_filename($r_jpg_name));
				if ($sub_jpg_num eq "1") {
					# yahooの1枚目の画像の場合は"_1"を削除
					$y_file_name = @$regist_mall_data_line[0].".jpg";
					$y_full_file_name = get_y_image_folder_name($y_file_count)."/".$y_file_name;
					$y_thumb_file_name = @$regist_mall_data_line[0]."s.jpg";
					$y_thumb_full_file_name = $y_s_over6_image_dir."/".$y_thumb_file_name;
					$y_file_count++;
				}
				else {
					# yahooの2枚目以降の画像	
					$y_file_count++;
					$y_file_name = @$regist_mall_data_line[0]."_".get_target_image_prefix($y_file_count).$sub_jpg_num.".jpg";
					$y_full_file_name = get_y_image_folder_name($y_file_count)."/".$y_file_name;
					$y_thumb_file_name = @$regist_mall_data_line[0]."_".get_target_image_prefix($y_file_count).$sub_jpg_num."s.jpg";
					$y_thumb_full_file_name = $y_s_over6_image_dir."/".$y_thumb_file_name;
				}
				copy( "$r_image_dir/$r_jpg_name", "$y_full_file_name" ) or die("ERROR!! $y_full_file_name copy failed.");		
				&image_resize($y_full_file_name, $y_thumb_full_file_name, 70, 70, 70);
				if ($y_file_count < 6) {
					push(@y_img_list,$y_full_file_name);
#					&add_y_zip($y_full_file_name);
				}
				else {
					push (@y_6over_img_list,$y_full_file_name);
#					&add_y_s_over6_zip($y_full_file_name, $y_file_name);
				}
				push (@y_6over_img_list,$y_thumb_full_file_name);
#				&add_y_s_over6_zip($y_thumb_full_file_name, $y_thumb_file_name);
				# 処理した画像ファイル名を保持
				my $separator="";
				if ($y_filename_list ne "") {
					$separator="/";
				}
				$r_filename_list.=$separator.$r_jpg_name;
				$y_filename_list.=$separator.$y_file_name;
			}
		}
	}		
	else {
		# バリエーション商品なので5桁code_7_listのファイル名
		# まず正面画像"_1"をリストの先頭にいれる
		foreach my $target_code_7 (@code_7_list) {
			if (get_5code($target_code_7) == get_5code(@$regist_mall_data_line[0])) {
				foreach my $r_jpg_name (@r_jpg_list) { 	
					my $sub_jpg_name = substr($r_jpg_name, 0, 7);	
					if ($target_code_7 eq $sub_jpg_name) {
						my $sub_jpg_num = substr($r_jpg_name, 8, get_image_numdigit_from_filename($r_jpg_name));
						if ($sub_jpg_num eq "1") {
							# "_1"の画像の場合の処理
							if ($y_file_count == 0) {
								# 1枚目の場合は番号を付加しない
								$y_file_name = get_5code($target_code_7).".jpg";
								$y_full_file_name = get_y_image_folder_name($y_file_count)."/".$y_file_name;
								$y_thumb_file_name = get_5code($target_code_7)."s.jpg";
								$y_thumb_full_file_name = $y_s_over6_image_dir."/".$y_thumb_file_name;
								$y_file_count++;
							}
							else {
								$y_file_count++;
								# 2枚目以降は連番を付与
								$y_file_name = get_5code($target_code_7)."_".get_target_image_prefix($y_file_count).$y_file_count.".jpg";
								$y_full_file_name = get_y_image_folder_name($y_file_count)."/".$y_file_name;
								$y_thumb_file_name = get_5code($target_code_7)."_".get_target_image_prefix($y_file_count).$y_file_count."s.jpg";
								$y_thumb_full_file_name = $y_s_over6_image_dir."/".$y_thumb_file_name;

							}				
							copy( "$r_image_dir/$r_jpg_name", "$y_full_file_name" ) or die("ERROR!! $y_full_file_name copy failed.");
							&image_resize($y_full_file_name, $y_thumb_full_file_name, 70, 70, 70);
							if ($y_file_count < 6) {
								push(@y_img_list,$y_full_file_name);
#								&add_y_zip($y_full_file_name);
							}
							else {
								push (@y_6over_img_list,$y_full_file_name);
#								&add_y_s_over6_zip($y_full_file_name, $y_file_name);
							}
							push (@y_6over_img_list,$y_thumb_full_file_name);
#							&add_y_s_over6_zip($y_thumb_full_file_name, $y_thumb_file_name);
							# 処理した画像ファイル名を保持
							my $separator="";
							if ($y_filename_list ne "") {
								$separator="/";
							}
							$r_filename_list.=$separator.$r_jpg_name;
							$y_filename_list.=$separator.$y_file_name;							
						}
					}
				}
			}
		}
		$y_file_count = $y_file_count-1;
		# "_1"以外の画像をリストに入れる
		foreach my $target_code_7 (@code_7_list) {
			if (get_5code($target_code_7) == get_5code(@$regist_mall_data_line[0])) {
				foreach my $r_jpg_name (@r_jpg_list) { 
					my $sub_jpg_name = substr($r_jpg_name, 0, 7);
					if ($target_code_7 eq $sub_jpg_name) {
						my $sub_jpg_num = substr($r_jpg_name, 8, get_image_numdigit_from_filename($r_jpg_name));
						if ($sub_jpg_num ne "1") {
							$sub_jpg_num = $sub_jpg_num+$y_file_count;
							$y_file_name = get_5code($target_code_7)."_".get_target_image_prefix($sub_jpg_num).$sub_jpg_num.".jpg";
							$y_full_file_name = get_y_image_folder_name($sub_jpg_num)."/".$y_file_name;
							$y_thumb_file_name = get_5code($target_code_7)."_".get_target_image_prefix($sub_jpg_num).$sub_jpg_num."s.jpg";
							$y_thumb_full_file_name = $y_s_over6_image_dir."/".$y_thumb_file_name;							
							copy( "$r_image_dir/$r_jpg_name", "$y_full_file_name" ) or die("ERROR!! $y_full_file_name copy failed.");
							&image_resize($y_full_file_name, $y_thumb_full_file_name, 70, 70, 70);
							if ($sub_jpg_num < 6) {
								push(@y_img_list,$y_full_file_name);
#								&add_y_zip("$y_full_file_name");
							}
							else {
								push (@y_6over_img_list,$y_full_file_name);
#								&add_y_s_over6_zip("$y_full_file_name", "$y_file_name");
							}
							push (@y_6over_img_list,$y_thumb_full_file_name);
#							&add_y_s_over6_zip($y_thumb_full_file_name, $y_thumb_file_name);
							# 処理した画像ファイル名を保持
							my $separator="";
							if ($y_filename_list ne "") {
								$separator="/";
							}
							$r_filename_list.=$separator.$r_jpg_name;
							$y_filename_list.=$separator.$y_file_name;
						}
					}
				}
			}
		}
	}
	push(@done_list, @$regist_mall_data_line[0]);
	$y_filename_lists{@$regist_mall_data_line[0]}=$y_filename_list;
	$r_filename_lists{@$regist_mall_data_line[0]}=$r_filename_list;
}

# ZIPファイルのクローズ
&terminate_y_zip(@y_img_list);
&terminate_y_s_over6_zip(@y_6over_img_list);
#&terminate_y_zip("$y_image_dir/y_pic_$y_zip_count.zip");
#&terminate_y_s_over6_zip("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");

#=================
# sabunファイルの情報に"親の画像枚数","バリエーション"を追加してregist_mall_data_file.csvを作成
if (!open $output_regist_mall_data_file_disc_correct, ">", $regist_mall_data_file_name_correct) {
	&output_log("ERROR!!($!) $regist_mall_data_file_name_correct open failed.");
	exit 1;
}
seek $input_regist_mall_data_file_disc, 0, 0;
$regist_mall_data_line = $input_regist_mall_data_csv->getline($input_regist_mall_data_file_disc);
for (my $i=0; $i < 12; $i++) {
	$output_regist_mall_data_csv_correct->combine(@$regist_mall_data_line[$i]) or die $output_regist_mall_data_csv_correct->error_diag();
	if ($i == 11) {
		print $output_regist_mall_data_file_disc_correct $output_regist_mall_data_csv_correct->string(), "\n";
	}
	else {
		print $output_regist_mall_data_file_disc_correct $output_regist_mall_data_csv_correct->string(), ",";
	}
}
while($regist_mall_data_line = $input_sabun_csv->getline($input_regist_mall_data_file_disc)){
	for (my $i=0; $i < 10; $i++) {
		$output_regist_mall_data_csv_correct->combine(@$regist_mall_data_line[$i]) or die $output_regist_mall_data_csv_correct->error_diag();
		print $output_regist_mall_data_file_disc_correct $output_regist_mall_data_csv_correct->string(), ",";
	}
	my $find_flag=0;
	while ( my ($code_9, $image_filename) = each %r_filename_lists ) {
		if ($code_9 eq @$regist_mall_data_line[0]) {
			$output_regist_mall_data_csv_correct->combine($image_filename) or die $output_regist_mall_data_csv_correct->error_diag();
			print $output_regist_mall_data_file_disc_correct $output_regist_mall_data_csv_correct->string(), ",";
			$find_flag=1;
			keys %r_filename_lists;
			last;
		}
	}
	if (!$find_flag) {
		$output_regist_mall_data_csv_correct->combine("") or die $output_regist_mall_data_csv_correct->error_diag();
		print $output_regist_mall_data_file_disc_correct $output_regist_mall_data_csv_correct->string(), ",";
	}
	$find_flag=0;
	while ( my ($code_9, $image_filename) = each %y_filename_lists ) {
		if ($code_9 eq @$regist_mall_data_line[0]) {
			$output_regist_mall_data_csv_correct->combine($image_filename) or die $output_regist_mall_data_csv_correct->error_diag();
			print $output_regist_mall_data_file_disc_correct $output_regist_mall_data_csv_correct->string(), "\n";
			$find_flag=1;
			keys %y_filename_lists;
			last
		}
	}
	if (!$find_flag) {
		$output_regist_mall_data_csv_correct->combine("") or die $output_regist_mall_data_csv_correct->error_diag();
		print $output_regist_mall_data_file_disc_correct $output_regist_mall_data_csv_correct->string(), "\n";
	}
}
close $output_regist_mall_data_file_disc_correct;
close $input_regist_mall_data_file_disc;

# 不要なファイルの削除
my $wd = Cwd::getcwd();
chdir $r_image_dir;
unlink<*.jpg>;
chdir $wd;
unlink $regist_mall_data_file_name;

# 処理終了
&output_log("Process is Success!!\n");
&output_log("**********END**********\n");

# CSVモジュールの終了処理
$input_goods_csv->eof;
$input_sabun_csv->eof;
$output_regist_mall_data_csv->eof;
# ファイルのクローズ
close $input_goods_file_disc;
close $input_sabun_file_disc;

close(LOG_FILE);

##########################################################################################
##############################  sub routin   #############################################
##########################################################################################

## 画像をリサイズする
sub image_resize() {
	( $img_resize->{in} , $img_resize->{out} , $img_resize->{width},  $img_resize->{height}, $img_resize->{quality}) = @_ ;
	# リサイズ条件の設定
	$img_resize->{ext}      = '.jpg';
	$img_resize->{exif_cut} =   1;
	$img_resize->{jpeg_prog} = 'convert -geometry %wx%h -quality %q -sharpen 10 %i %o';
	$img_resize->{png_prog}  = $img_resize->{jpeg_prog};
	$img_resize->{gif_prog}  = $img_resize->{jpeg_prog};
	# リサイズ
	$img_resize->resize;
}

## Yahoo用のZIPファイルに画像をファイルを追加
sub add_y_zip() {
	$y_zip->addFile("$_[0]");
	if (!(++$y_zip_count % $y_image_max)) {
		# 新しいZIPファイルにする
		terminate_y_zip("$y_image_dir/y_pic_$y_zip_count".".zip");
		$y_zip = Archive::Zip->new();
	}
}

## Yahoo用のZIPファイルにthumbnail, 6以上の画像を追加
sub add_y_s_over6_zip() {
	$y_s_over6_zip->addFile("$_[0]", "$_[1]");
		if (!(++$y_s_over6_zip_count % $y_s_over6_image_max)) {
		# 新しいZIPファイルにする
		terminate_y_s_over6_zip("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");
		$y_s_over6_zip = Archive::Zip->new();
	}
}

## Yahoo用のZIPファイルの終了処理
sub terminate_y_zip() {
	$y_zip_count=0;
	for (my $i = 0; $i <= $#y_img_list; $i++){
		if (!(++$y_zip_count % $y_image_max)) {
			my $status = $y_zip->writeToFileNamed("$y_image_dir/y_pic_$y_zip_count.zip");
			if ($status != 0) {
				output_log("!!!!!zip error [$status] filename[$_[0]]\n");
				exit 1;
			}
			$y_zip = Archive::Zip->new();
		}
		my $y_img_list_name = substr($y_img_list[$i],29);
		$y_zip->addFile($y_img_list[$i],$y_img_list_name);
	}
	my $status = $y_zip->writeToFileNamed("$y_image_dir/y_pic_$y_zip_count.zip");
	if ($status != 0) {
		output_log("!!!!!zip error [$status] filename[$_[0]]\n");
		exit 1;
	}
}

## Yahoo用のZIPファイルの終了処理
sub terminate_y_s_over6_zip() {
	$y_s_over6_zip_count =0;
	for (my $i = 0; $i <= $#y_6over_img_list; $i++){
		if (!(++$y_s_over6_zip_count % $y_s_over6_image_max)) {
			my $status = $y_s_over6_zip->writeToFileNamed("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");
			if ($status != 0) {
				output_log("!!!!!zip error [$status] filename[$_[0]]\n");
				exit 1;
			}
			$y_s_over6_zip = Archive::Zip->new();
		}
		my $y_6over_img_list_name = substr($y_6over_img_list[$i],37);
		$y_s_over6_zip->addFile($y_6over_img_list[$i],$y_6over_img_list_name);
	}
	my $status = $y_s_over6_zip->writeToFileNamed("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");
	if ($status != 0) {
		output_log("!!!!!zip error [$status] filename[$_[0]]\n");
		exit 1;
	}
}

## ログ出力
sub output_log() {
	my $day=::to_YYYYMMDD_string();
	my $old_fh = select(LOG_FILE);
	my $old_dolcol = $|;
	$| = 1;
	print"[$day]:$_[0]";
	$| = $old_dolcol;
	select($old_fh);
	print"[$day]:$_[0]";
}

## 現在日時取得関数
sub to_YYYYMMDD_string() {
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

sub get_7code {
	return substr(delete_double_quotation($_[0]), 0, 7);
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

## 指定されたカテゴリ名に対応するカテゴリをXMLファイルから取得する
sub get_brandname_from_xml {
	my $category_name = $_[0]; 
	my $info_name = "r_directory";  
	#brand.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$brand_xml_filename",ForceArray=>['brand']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_category_name = $xml_data->{brand}[$count]->{category_name};
		if (!$xml_category_name) {
			# 全て読み出したら終了
			last;
		}
		Encode::_utf8_off($xml_category_name);
		Encode::from_to( $xml_category_name, 'utf8', 'shiftjis' );
		chomp($xml_category_name);
		# カテゴリ名のチェック
		if ($category_name  eq $xml_category_name){
			$info = $xml_data->{brand}[$count]->{$info_name};
			if($info) {
				Encode::_utf8_off($info);
				Encode::from_to( $info, 'utf8', 'shiftjis' );
			}
			else {
				$info="";
			}
			last;
		}
		$count++;
	}
	return $info;
}

## 指定されたフォルダ名でフォルダを作成する。すでにフォルダが存在する場合は何もしない
sub create_dir {
	if(-d $_[0]) {
		return 0;
	}
	mkpath($_[0]) or die("ERROR!! $_[0] create failed.");
}

sub get_target_image_prefix {
	my $file_count=$_[0];
	my $target_image_prefix = "";
	return $target_image_prefix;
}

sub get_y_image_folder_name {
	my $file_count=$_[0];
	my $y_image_folder_name = "";
	if ($file_count < 6) {
		$y_image_folder_name = $y_image_dir;
	}			
	else {
		$y_image_folder_name = $y_s_over6_image_dir;
	}
	return $y_image_folder_name;
}

sub get_image_numdigit_from_filename {
	my $file_name=$_[0];
	# ファイル名からファイル番号を桁数を意識して取得
	my $digit_count=0;
	my $file_count=substr($file_name, 8, 2);
	if (index($file_count, '.') != -1) {
		$digit_count = 1;
	}
	else {
		$digit_count = 2;
	}
	return $digit_count;
}

sub get_keynumber_from_filename {
	my $keynumber = substr($_[0], 0, 7);
	my $image_num = substr($_[0], 8, get_image_numdigit_from_filename($_[0]));
	if (get_image_numdigit_from_filename($_[0]) == 1) {
		$image_num = "0".$image_num;
	}
	$keynumber .= $image_num;
	return $keynumber;
}