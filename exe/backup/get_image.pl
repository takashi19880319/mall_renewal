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
use LWP::UserAgent;
use LWP::Simple;
use HTML::TreeBuilder;

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
my $regist_mall_data_file_name="$output_dir"."/"."regist_mall_data_file.csv";
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
my %rakuten_target_image_lists;
my %yahoo_target_image_lists;
my %target_variation;
my @code_7_list=();
# _6未満の画像のリスト
my @y_img_list = ();
# _6以上の画像のリスト
my @y_6over_img_list = ();
# 掲載する画像のリスト
my @new_img_url_list =();
my @done_list_5 =();
my $sabun_line = $input_sabun_csv->getline($input_sabun_file_disc);
while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){
	my $code_9=@$sabun_line[0];
	my $target_code_5 = &get_5code($code_9);
	my $total_image_cnt=0;
	my $done_flag =0;
	# 処理済の親商品はスキップ
	foreach my $done_list_5 (@done_list_5) {
		if($done_list_5 == $target_code_5) {
			$done_flag = 1;
		}
	}
	if ($done_flag == 1) {
		next;
	}
	# 親商品毎にリストの初期化
	${rakuten_target_image_lists{$code_9}};
	${yahoo_target_image_lists{$code_9}};
	my $target_code_7 = get_7code(@$sabun_line[0]);
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
			if ($brand_name eq "") {
				$brand_name = get_brandname_from_xml(@$goods_line[1]);
			}
		}
	}
	# 先頭に/c/の画像を入れる
	my $goods_num;
	# goods.csvに5桁が合致する商品が一つしかなかったのでバリエーション商品ではない
	if ($find_5code_count == 1) {
		$goods_num = $code_9;
		$target_variation{$code_9}=0;
	}
	# goods.csvに5桁が合致する商品が複数あったのでバリエーション商品
	else {
		$goods_num = $target_code_5;
		$target_variation{$code_9}=1;
	}
	# スクレイピングでGLOBERのページから画像をDLし、楽天店用に保存
	@new_img_url_list =();
	&get_img_list($target_code_5);
	# cの画像の画像URL
	my $img_c_url = "http://glober.jp/img/c/$goods_num.jpg";
	# 取得するリストにcの画像も追加
	unshift(@new_img_url_list,$img_c_url);
	my $rtn=0;
	my $cnt=0;
	my $c_find_flag = 0;
	# リスト内の画像を取得する
	my $img_cnt =1;
	# ヤフー店の1～5保存用ファイル名
	my $y_file_name;
	# ヤフー店の1～5画像パス
	my $y_full_file_name;
	# ヤフー店の6～,sの保存用ファイル名
	my $y_s_over6_file_name;
	# ヤフー店の6～,s画像パス
	my $y_s_over6_full_file_name;
	# 取得する画像リストのすべての画像をDL
	for (my $i=0; $i <= $#new_img_url_list; $i++){
		# GLOBERの商品画像URL
		my $glober_goods_img_url = $new_img_url_list[$i];	
		# 画像を取得する
		$rtn = system("wget.exe -q -P $r_image_dir $glober_goods_img_url");
		$glober_goods_img_url =~ s/\.jpg//g;
		# 楽天店の保存用ファイル名
		my $rakuten_file_name = $glober_goods_img_url.".jpg";
		$rakuten_file_name =~ s/http:\/\/glober\.jp\/img\/c\///g;
		$rakuten_file_name =~ s/http:\/\/glober\.jp\/img\/goods\/\d{1,2}\///g;
		# /c/または/nn/を抽出
		$glober_goods_img_url =~ /\/c\//;
		$glober_goods_img_url =~ /\/\d{1,2}\//;
		#マッチしたディレクトリを返している
		$cnt = $&;
		$cnt =~ s/\///g;
		# /c/に画像がない場合、スキップする
		if ($rtn){
			my $warning_str = "WARNING!! $glober_goods_img_url カラーバリエーション画像がありません。";
			Encode::from_to( $warning_str, 'utf8', 'shiftjis' );
			&output_log("$warning_str.\n");
			next;
		}
		if ($cnt eq "c") {
			# http://glober.jp/img/c/を削除
			$glober_goods_img_url =~ s/http:\/\/glober\.jp\/img\/c\///g;
			# フォルダ作成
			my $target_dir=$r_image_dir."/".$brand_name."/".$cnt;
			&create_dir($target_dir);
			# ブランド毎_n毎のフォルダに格納する。※リサイズはいらない
			# 楽天用
			copy($r_image_dir."/".$glober_goods_img_url.".jpg", $target_dir."/".$rakuten_file_name) or die ("ERROR!!".$r_image_dir."\\".$rakuten_file_name." copy failed.");
			&image_resize($r_image_dir."/".$glober_goods_img_url.".jpg", $target_dir."/".$glober_goods_img_url."s.jpg", 70, 70, 70);
			# ヤフー用
			$y_file_name = $goods_num.".jpg";
			$y_full_file_name = $y_image_dir."/".$goods_num.".jpg";
			$y_s_over6_file_name = $goods_num."s.jpg";
			$y_s_over6_full_file_name = $y_s_over6_image_dir."/".$goods_num."s.jpg";
			copy($r_image_dir."/".$glober_goods_img_url.".jpg", $y_full_file_name) or die ("ERROR!!".$y_image_dir."\\".$goods_num."jpg"." copy failed.");
			&image_resize($y_full_file_name, $y_s_over6_full_file_name, 70, 70, 70);
			# 1～5までの中にZIPする
			&add_y_zip($y_full_file_name,$y_file_name);
			# 6～,sの中にZIPする
			&add_y_s_over6_zip($y_s_over6_full_file_name,$y_s_over6_file_name);
			$c_find_flag = 1;
		}
		else{
			# http://glober.jp/img/goods/nn/を削除
			$glober_goods_img_url =~ s/http:\/\/glober\.jp\/img\/goods\/\d{1,2}\///g;
			# フォルダ作成
			my $target_dir=$r_image_dir."/".$brand_name."/".$cnt;
			&create_dir($target_dir);
			# ブランド毎_n毎のフォルダに格納する。
			# 楽天用
			copy($r_image_dir."/".$glober_goods_img_url.".jpg", $target_dir."/".$rakuten_file_name) or die ("ERROR!!".$r_image_dir."\\".$rakuten_file_name." copy failed.");
			&image_resize($r_image_dir."/".$glober_goods_img_url.".jpg", $target_dir."/".$glober_goods_img_url."s.jpg", 70, 70, 70);
			# ヤフー用
			# カラーバリエーション画像がない場合の1番目の画像
			if($i == 1 && $c_find_flag == 0){
				$y_file_name = $goods_num.".jpg";
				$y_full_file_name = $y_image_dir."/".$goods_num.".jpg";
				$y_s_over6_file_name = $goods_num."s.jpg";
				$y_s_over6_full_file_name = $y_s_over6_image_dir."/".$goods_num."s.jpg";
				copy($r_image_dir."/".$glober_goods_img_url.".jpg", $y_full_file_name) or die ("ERROR!!".$y_image_dir."\\".$rakuten_file_name." copy failed.");
				&image_resize($y_full_file_name, $y_s_over6_full_file_name, 70, 70, 70);
				# 1～5までの中にZIPする
				&add_y_zip($y_full_file_name,$y_file_name);
				# 6～,sの中にZIPする
				&add_y_s_over6_zip($y_s_over6_full_file_name,$y_s_over6_file_name);
				
			}
			else {
				$img_cnt++;
				if($img_cnt<=5){
					$y_file_name = $goods_num."_$img_cnt".".jpg";
					$y_full_file_name = $y_image_dir."/".$goods_num."_$img_cnt".".jpg";
					$y_s_over6_file_name = $goods_num."_$img_cnt"."s.jpg";
					$y_s_over6_full_file_name = $y_s_over6_image_dir."/".$goods_num."_$img_cnt"."s.jpg";;
					copy($r_image_dir."/".$glober_goods_img_url.".jpg", $y_full_file_name) or die ("ERROR!!".$r_image_dir."\\".$rakuten_file_name." copy failed.");
					&image_resize($y_full_file_name, $y_s_over6_full_file_name, 70, 70, 70);
					# 1～5までの中にZIPする
					&add_y_zip($y_full_file_name,$y_file_name);
					# 6～,sの中にZIPする
					&add_y_s_over6_zip($y_s_over6_full_file_name,$y_s_over6_file_name);
				}
				else {
					$y_file_name = $goods_num."_$img_cnt".".jpg";
					$y_full_file_name = $y_s_over6_image_dir."/".$goods_num."_$img_cnt".".jpg";
					$y_s_over6_file_name = $goods_num."_$img_cnt"."s.jpg";
					$y_s_over6_full_file_name = $y_s_over6_image_dir."/".$goods_num."_$img_cnt"."s.jpg";
					copy($r_image_dir."/".$glober_goods_img_url.".jpg", $y_full_file_name) or die ("ERROR!!".$r_image_dir."\\".$goods_num."_$img_cnt"."jpg"." copy failed.");
					&image_resize($y_full_file_name, $y_s_over6_full_file_name, 70, 70, 70);
					# 6～,sの中にZIPする
					&add_y_s_over6_zip($y_full_file_name,$y_file_name);
					# 6～,sの中にZIPする
					&add_y_s_over6_zip($y_s_over6_full_file_name,$y_s_over6_file_name);
				}
			}
		}
		# 楽天店に掲載する画像のリストを配列に入れる
		push(@{$rakuten_target_image_lists{$code_9}},$rakuten_file_name);
		# ヤフー店に掲載する画像のリストを配列に入れる
		push(@{$yahoo_target_image_lists{$code_9}},$y_file_name);
	}
	$total_image_cnt = @new_img_url_list;
=pod
	my $chk = 157831111;
	if($code_9 == $chk){
		while (my($pref, $city) = each(%rakuten_target_image_lists)) {
		  #
		  # ハッシュの値(配列)を全て巡回する
		  foreach (@{$city}) {
			if($chk == $pref){
				print "$pref = $_\n"; # 出力
			}
		  }
		  print "\n"; # ハッシュ毎に空行を入れる
		}
	}
=cut
=pod
	my $status = $zip->writeToFileNamed($zipfile);
	if ($status != 'AZ_OK') {
		unlink("$zipfile") if (-e "$zipfile");
		print "$zipfileが作成されません";
		exit;
	}
=cut
	# cがあるとき（c_find_flag=1の時）+処理される
	if(!$c_find_flag){
		$total_image_cnt++;
	}
	$target_image_num{$code_9}=$total_image_cnt;
	push (@done_list_5,$target_code_5)
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
		if($i == 7){
			$output_regist_mall_data_csv->combine(@$sabun_line[$i]) or die $output_regist_mall_data_csv->error_diag();
		}
		else {
			$output_regist_mall_data_csv->combine(@$sabun_line[$i]) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
		}
	}
	if(@$sabun_line[7] eq "d"){
		print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), "\n";
		next;
	}
	my $find_flag=0;
	while ( my ($code_9, $image_cnt) = each %target_image_num ) {
		if ($code_9 eq @$sabun_line[0]) {
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine($image_cnt) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine($target_variation{$code_9}) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine(&output_rakuten_img_list($code_9)) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine(&output_yahoo_img_list($code_9)) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), "\n";
			$find_flag=1;
		}
	}
	if (!$find_flag) {
		print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), "\n";
	}
}
=pod
while($sabun_line = $input_sabun_csv->getline($input_sabun_file_disc)){
	my $sabun_code = @$sabun_line[0];
	$sabun_code =~ s/"//g;
	my $multi_info_find_flag=0;
	while ( my ($target_code_9, $image_cnt) = each %target_image_num ) {
		if($sabun_code == $target_code_9){
			print $target_code_9."\n";
			for (my $i=0; $i < 8; $i++) {
				$output_regist_mall_data_csv->combine(@$sabun_line[$i]) or die $output_regist_mall_data_csv->error_diag();
				print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			}
			$output_regist_mall_data_csv->combine($image_cnt) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine($target_variation{$target_code_9}) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine(&output_rakuten_img_list($target_code_9)) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			$output_regist_mall_data_csv->combine(&output_yahoo_img_list($target_code_9)) or die $output_regist_mall_data_csv->error_diag();
			print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), "\n";
			$multi_info_find_flag=1;
			last;
		}
	}
	if($multi_info_find_flag == 0){
		print $sabun_code."\n";
		for (my $i=0; $i < 8; $i++) {
			if($i==7){
				$output_regist_mall_data_csv->combine(@$sabun_line[$i]) or die $output_regist_mall_data_csv->error_diag();
				print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), "\n";
			}
			else {
				$output_regist_mall_data_csv->combine(@$sabun_line[$i]) or die $output_regist_mall_data_csv->error_diag();
				print $output_regist_mall_data_file_disc $output_regist_mall_data_csv->string(), ",";
			}
		}
	}
}
=cut
close $output_regist_mall_data_file_disc;

# ZIPファイルのクローズ
# add_File途中の画像をZIP
&terminate_y_zip("$y_image_dir/y_pic_$y_zip_count.zip");
&terminate_y_s_over6_zip("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");

# 不要なファイルの削除
my $wd = Cwd::getcwd();
chdir $r_image_dir;
unlink<*.jpg>;
chdir $wd;
# unlink $regist_mall_data_file_name;

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

## HTMLを取得して、掲載する画像のリストを作成する
sub get_img_list(){
	# GLOBERの商品画像URL
	my $glober_goods_url = "http://glober.jp/g/g"."$_[0]";
	# HTMLを取得
	# LWP::Simpleの「get」関数を使用                                                
	# GLOBERの商品詳細HTML取得
	my $glober_goods_new = get($glober_goods_url) or die "Couldn't get it!";
	$glober_goods_new = Encode::encode('Shift_JIS', $glober_goods_new);
	# 画像のリストを作成する
	my $tree_new = HTML::TreeBuilder->new;
	$tree_new->parse($glober_goods_new);
	my @goods_img_url_list_place =  $tree_new->look_down('class', 'thumbList fixHeight clearfix')->find('a');
	for my $img_li (@goods_img_url_list_place) {
	    my $img_src = "";
	    $img_src = $img_li->attr('rev');
	    my $img_url = "http://glober.jp".$img_src;
	    push (@new_img_url_list,$img_url);
	}
}

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
	$y_zip->addFile("$_[0]","$_[1]");
	if (!(++$y_zip_count % $y_image_max)) {
		# 新しいZIPファイルにする
		terminate_y_zip("$y_image_dir/y_pic_$y_zip_count".".zip");
		$y_zip = Archive::Zip->new();
	}
}

## Yahoo用のZIPファイルにthumbnail, 6以上の画像を追加
sub add_y_s_over6_zip() {
	$y_s_over6_zip->addFile("$_[0]","$_[1]");
		if (!(++$y_s_over6_zip_count % $y_s_over6_image_max)) {
		# 新しいZIPファイルにする
		terminate_y_s_over6_zip("$y_s_over6_image_dir/y_s_over6_$y_s_over6_zip_count.zip");
		$y_s_over6_zip = Archive::Zip->new();
	}
}

## Yahoo用のZIPファイルの終了処理
sub terminate_y_zip() {
	$y_zip->writeToFileNamed("$_[0]");
}

## Yahoo用のZIPファイルの終了処理
sub terminate_y_s_over6_zip() {
	$y_s_over6_zip->writeToFileNamed("$_[0]");
}

sub output_rakuten_img_list(){
	my $rakuten_img_list="";
	my $slash = "/";
	while (my ($sabun_code_9, $value) = each(%rakuten_target_image_lists)) {
		if($_[0] == $sabun_code_9){
			 foreach (@{$value}) {
			 	if($rakuten_img_list eq ""){$rakuten_img_list .= $_;}
			 	else{$rakuten_img_list .= $slash.$_;}
			}
		}
	}
	return $rakuten_img_list;
}

sub output_yahoo_img_list(){
	my $yahoo_img_list="";
	my $slash = "/";
	while (my($sabun_code_9, $value) = each(%yahoo_target_image_lists)) {
		if($_[0] == $sabun_code_9){
			foreach (@{$value}) {
				if($yahoo_img_list eq ""){$yahoo_img_list .= $_;}
			 	else{$yahoo_img_list .= $slash.$_;}
			}
		}
	}
	return $yahoo_img_list;
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