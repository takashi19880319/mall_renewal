# create_mall_entry_data.pl
# author:Takashi.Hashiguchi
# date:2014/6/1

#========== 改訂履歴 ==========
# date:2012/11/11 modify
# ・以下のファイルの商品番号5桁管理対応
#  -goods_supp.csv
#  -goods_spec.csv
#  -genre_goods.csv
#-----
# date:2012/11/23 modify
# ○サイズチャートの修正
#   ・最後の</tr>が一個多い
#   ・<td><table>が入ってくる時がある
# ○楽天のモバイル用説明文について
#   →楽天「モバイル用商品説明文」、ヤフー「explanation」は、
#    商品コメントのテキストをそのまま引用
#   ・<br>と<tr>を削除
# ○カラー、サイズのスペック表示について
#   ・カラーとサイズの参照はgoods.csv
#    amazon_specとyahooにサイズが入ってこない
# ○「サイズの測り方について」
#   文字化け全ての商品に対して「サイズの測り方について」のリンクをサイズチャートの
#   下に表示
#   ・リンク先の変更(bottomにリンクされている対応)
#   ・ヤフーも同様に変更
#   ※現状はサイズ展開のある商品（7桁）のみにリンクが出力されているかと思います。
#     サイズ展開のない商品（9桁）にも出力して頂けないでしょうか？
# ○9以上の画像に対応
#-----
# date:2014/03/13 addition
# ○商品説明欄に記入のある消費税率バナーのHTMLをカット
#　　・サブルーチンのsub create_r_pc_goods_specの修正
#　　・正規表現で不要な文言を削除
# ○フェリージの認証の店舗URLを置換する
#　　・サブルーチンの楽天店はsub create_r_pc_goods_specの修正
#   ヤフー店はsub create_y_captionの修正
#  ・正規表現でグローバーのURLとHFFのURLを置換
#　○楽天店の商品画像URLを9枚まで表示させるプログラム追記
#  ・サブルーチンのsub create_r_goods_image_urlに9枚までの画像を追記
#
#-----
# date:2014/03/27 addition
# ○楽天のitem.csvに「再入荷お知らせボタン」項目を追加
#　常に1を出力する。
#-----
# date:2014/04/07 addition
# ○楽天のitem.csvに「ポイント変倍率」「ポイント変倍率期間」項目を追加。
# ○brand.xmlの属性「brand_point」と「brand_point_term」を追加。
# ポイント10倍にしたいブランドのbrand_point欄に10を入力する。brand_point_termにはstartday_finishdayを入力する。
# subルーチンを作成。
# ○楽天のitem.csvに「スマートフォン用商品説明文」項目を追加。
# モバイル用商品説明文と同じものにする。
#-----
# date:2014/04/09 addition
# ○yahooのydata.csvの「additional3」項目を修正
# ・ディスプレイにより、実物と色、イメージが異なる事がございます。あらかじめご了承ください。とお直しについてのリンクを追加。
# ○楽天、ヤフーともにサイズチャートの</tr>の重複を削除
# サブルーチンのcreate_r_pc_goods_specとcreate_y_captionの置き換えを修正した。
#　テーブルの最後の</tr></table>→</table>
#
########################################################
## Glober(本店)に登録されている商品をHFF楽天店,Yahoo!店の各モール店
## に登録する為のデータファイルを作成します。 
## 【入力ファイル】
## 本プログラムを実行する際に下記の入力ファイルが実行ディレクトリに存在している必要があります。
## ・goods.csv                                                             
## ・goods_spec.csv
## ・goods_supp.csv
## ・genre_goods.csv
##    -本店に登録されている全商品のデータ。ecbeingよりダウンロード。
## ・sabun_YYYYMMDD.csv
##    -モール店に登録する商品データ。基本的には本店とモール店の差分になります。
##     1カラム目に商品番号が入っている必要があります。
## ・image_num.csv
##    -各商品の画像枚数のデータ。事前にget_image.plで生成。
##     sabun_YYYYMMDD.csvのデータ中SKUのものはまとめられています。
## 【参照ファイル】
## ・brand.xml
## ・category.xml
## ・goods_spec.xml
## 【出力ファイル】
## <楽天用データ>
## ・item.csv
##    -楽天店用登録データ
## ・select.csv
##    -楽天店用バリエーションデータ
## ・item-cat.csv
##    -楽天店用カテゴリ分けデータ
## <Yahoo!店用データ>
## ・y_data.csv
##    -Yahoo!店用登録データ
## ・y_quantity.csv
##    -Yahoo!店用在庫データ
## 【ログファイル】
## ・create_mall_entry_data_yyyymmddhhmmss.log
##    -エラー情報などを出力
########################################################

#/usr/bin/perl

use strict;
use warnings;
use Cwd;
use Encode;
use XML::Simple;
use Text::ParseWords;
use Text::CSV_XS;
use File::Path;

####################
##　ログファイル
####################
# ログファイルを格納するフォルダ名
my $output_log_dir="./../log";
# ログフォルダが存在しない場合は作成
unless (-d $output_log_dir) {
	if (!mkdir $output_log_dir) {
		&output_log("ERROR!!($!) create $output_log_dir failed\n");
		exit 1;
	}
}
#　ログファイル名
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
my $time_str = sprintf("%04d%02d%02d%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $log_file_name="$output_log_dir"."/"."create_mall_entry_data"."$time_str".".log";
# ログファイルのオープン
if(!open(LOG_FILE, "> $log_file_name")) {
	print "ERROR!!($!) $log_file_name open failed.\n";
	exit 1;
}

####################
##　入力ファイルの存在チェック
####################
#入力ファイル名
my $input_goods_file_name="goods.csv";
my $input_goods_spec_file_name="goods_spec.csv";
my $input_goods_supp_file_name="goods_supp.csv";
my $input_genre_goods_file_name="genre_goods.csv";
my $input_dl_select_file_name="dl-select.csv";
my $input_regist_mall_data_file_name="regist_mall_data_file.csv";
#入力ファイル配置ディレクトリのオープン
my $current_dir=Cwd::getcwd();
my $input_dir ="$current_dir"."/..";
if (!opendir(INPUT_DIR, "$input_dir")) {
	&output_log("ERROR!!($!) $input_dir open failed.");
	exit 1;
}
#　入力ファイルの有無チェック
my $goods_file_find=0;
my $goods_spec_file_find=0;
my $goods_supp_file_find=0;
my $genre_goods_file_find=0;
my $dl_select_file_find=0;
my $regist_mall_data_file_find=0;
while (my $current_dir_file_name = readdir(INPUT_DIR)){
	if($current_dir_file_name eq $input_goods_file_name) {
		$goods_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_goods_spec_file_name) {
		$goods_spec_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_goods_supp_file_name) {
		$goods_supp_file_find=1;
		next;
	}
	elsif($current_dir_file_name eq $input_genre_goods_file_name) {
		$genre_goods_file_find=1;
		next;
	}
	elsif(index($current_dir_file_name, "dl-select", 0) != -1) {
		if($dl_select_file_find){
			next;
		}
		else{
			$dl_select_file_find=1;
			$input_dl_select_file_name=$current_dir_file_name;
			next;
		}
	}
	elsif($current_dir_file_name eq $input_regist_mall_data_file_name) {
		$regist_mall_data_file_find=1;
		next;
	}
}
closedir(INPUT_DIR);
if (!$goods_file_find) {
	#goods.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_file_name.\n");
}
if (!$goods_spec_file_find) {
	#goods_spec.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_spec_file_name.\n");
}
if (!$goods_supp_file_find) {
	#goods_supp.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_goods_supp_file_name.\n");
}
if (!$genre_goods_file_find) {
	#genre_goods.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_genre_goods_file_name.\n");
}
if (!$dl_select_file_find) {
	#dl-select.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_dl_select_file_name.\n");
}
if (!$regist_mall_data_file_find) {
	#regist_mall_data_file_name.csvファイルがカレントディレクトリに存在しない
	&output_log("ERROR!! Not exist $input_regist_mall_data_file_name.\n");
}

if (!$goods_file_find || !$goods_spec_file_find || !$goods_supp_file_find || !$genre_goods_file_find || !$dl_select_file_find || !$regist_mall_data_file_find) {
	exit 1;
}

####################
##　参照ファイルの存在チェック
####################
my $brand_xml_filename="brand.xml";
my $goods_spec_xml_filename="goods_spec.xml";
my $category_xml_filename="category.xml";
my $r_size_tag_xml_filename="r_size_tag.xml";
#参照ファイル配置ディレクトリのオープン
my $ref_dir ="$current_dir"."/xml";
if (!opendir(REF_DIR, "$ref_dir")) {
	&output_log("ERROR!!($!) $ref_dir open failed.");
	exit 1;
}
#　参照ファイルの有無チェック
my $brand_xml_file_find=0;
my $goods_spec_xml_file_find=0;
my $category_xml_file_find=0;
my $r_size_tag_xml_file_find=0;
while (my $ref_dir_file_name = readdir(REF_DIR)){
	if($ref_dir_file_name eq $brand_xml_filename) {
		$brand_xml_file_find=1;
		next;
	}
	elsif($ref_dir_file_name eq $goods_spec_xml_filename) {
		$goods_spec_xml_file_find=1;
		next;
	}
	elsif($ref_dir_file_name eq $category_xml_filename) {
		$category_xml_file_find=1;
		next;
	}
	elsif($ref_dir_file_name eq $r_size_tag_xml_filename) {
		$r_size_tag_xml_file_find=1;
		next;
	}
}
closedir(REF_DIR);
if (!$brand_xml_file_find) {
	#brand.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $brand_xml_filename.\n");
}
if (!$goods_spec_xml_file_find) {
	#goods_spec.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $goods_spec_xml_filename.\n");
}
if (!$category_xml_file_find) {
	#category.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $category_xml_filename.\n");
}
if (!$r_size_tag_xml_file_find) {
	#r_sizetag.xmlファイルが存在しない
	&output_log("ERROR!!($!) Not exist $r_size_tag_xml_filename.\n");
}
if (!$brand_xml_file_find || !$goods_spec_xml_file_find || !$category_xml_file_find || !$r_size_tag_xml_file_find) {
	exit 1;
}
$brand_xml_filename="$ref_dir"."/"."$brand_xml_filename";
$goods_spec_xml_filename="$ref_dir"."/"."$goods_spec_xml_filename";
$category_xml_filename="$ref_dir"."/"."$category_xml_filename";
$r_size_tag_xml_filename="$ref_dir"."/"."$r_size_tag_xml_filename";

####################
##　入力ファイルのオープン
####################
#CSVファイル用モジュールの初期化
my $input_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_spec_csv = Text::CSV_XS->new({ binary => 1 });
my $input_goods_supp_csv = Text::CSV_XS->new({ binary => 1 });
my $input_genre_goods_csv = Text::CSV_XS->new({ binary => 1 });
my $input_regist_mall_data_csv = Text::CSV_XS->new({ binary => 1 });
#入力ファイルのオープン	
$input_goods_file_name="$input_dir"."/"."$input_goods_file_name";
my $input_goods_file_disc;
if (!open $input_goods_file_disc, "<", $input_goods_file_name) {
	&output_log("ERROR!!($!) $input_goods_file_name open failed.");
	exit 1;
}	
$input_goods_spec_file_name="$input_dir"."/"."$input_goods_spec_file_name";
my $input_goods_spec_file_disc;
if (!open $input_goods_spec_file_disc, "<", $input_goods_spec_file_name) {
	&output_log("ERROR!!($!) $input_goods_spec_file_name open failed.");
	exit 1;
}	
$input_goods_supp_file_name="$input_dir"."/"."$input_goods_supp_file_name";
my $input_goods_supp_file_disc;
if (!open $input_goods_supp_file_disc, "<", $input_goods_supp_file_name) {
	&output_log("ERROR!!($!) $input_goods_supp_file_name open failed.");
	exit 1;
}	
$input_genre_goods_file_name="$input_dir"."/"."$input_genre_goods_file_name";
my $input_genre_goods_file_disc;
if (!open $input_genre_goods_file_disc, "<", $input_genre_goods_file_name) {
	&output_log("ERROR!!($!) $input_genre_goods_file_name open failed.");
	exit 1;
}	
$input_regist_mall_data_file_name="$input_dir"."/"."$input_regist_mall_data_file_name";
my $input_regist_mall_data_file_disc;
if (!open $input_regist_mall_data_file_disc, "<", $input_regist_mall_data_file_name) {
	&output_log("ERROR!!($!) $input_regist_mall_data_file_name open failed.");
	exit 1;
}	

####################
##　出力ファイルのオープン
####################
#出力ディレクトリ
my $output_rakuten_data_dir="../rakuten_up_data";
my $output_yahoo_data_dir="../yahoo_up_data";
#出力ファイル名
my $output_item_file_name="$output_rakuten_data_dir"."/"."item.csv";
my $output_resetitem_file_name="$output_rakuten_data_dir"."/"."reset-item.csv";
my $output_deleteitem_file_name="$output_rakuten_data_dir"."/"."delete-item.csv";
my $output_select_file_name="$output_rakuten_data_dir"."/"."select.csv";
my $output_itemcat_file_name="$output_rakuten_data_dir"."/"."item-cat.csv";
my $output_ydata_file_name="$output_yahoo_data_dir"."/"."ydata.csv";
my $output_yquantity_file_name="$output_yahoo_data_dir"."/"."yquantity.csv";
#出力先ディレクトリの作成
unless(-d $output_rakuten_data_dir) {
	# 存在しない場合はフォルダ作成
	if(!mkpath($output_rakuten_data_dir)) {
		output_log("ERROR!!($!) $output_rakuten_data_dir create failed.");
		exit 1;
	}
}
unless(-d $output_yahoo_data_dir) {
	# 存在しない場合はフォルダ作成
	if(!mkpath($output_yahoo_data_dir)) {
		output_log("ERROR!!($!) $output_yahoo_data_dir create failed.");
		exit 1;
	}
}
#出力用CSVファイルモジュールの初期化
my $output_item_csv = Text::CSV_XS->new({ binary => 1 });
my $output_resetitem_csv = Text::CSV_XS->new({ binary => 1 });
my $output_deleteitem_csv = Text::CSV_XS->new({ binary => 1 });
my $output_select_csv = Text::CSV_XS->new({ binary => 1 });
my $output_itemcat_csv = Text::CSV_XS->new({ binary => 1 });
my $output_ydata_csv = Text::CSV_XS->new({ binary => 1 });
my $output_yquantity_csv = Text::CSV_XS->new({ binary => 1 });
#出力ファイルのオープン
my $output_item_file_disc;
if (!open $output_item_file_disc, ">", $output_item_file_name) {
	&output_log("ERROR!!($!) $output_item_file_name open failed.");
	exit 1;
}
my $output_resetitem_file_disc;
if (!open $output_resetitem_file_disc, ">", $output_resetitem_file_name) {
	&output_log("ERROR!!($!) $output_item_file_name open failed.");
	exit 1;
}
my $output_deleteitem_file_disc;
if (!open $output_deleteitem_file_disc, ">", $output_deleteitem_file_name) {
	&output_log("ERROR!!($!) $output_item_file_name open failed.");
	exit 1;
}	
my $output_select_file_disc;
if (!open $output_select_file_disc, ">", $output_select_file_name) {
	&output_log("ERROR!!($!) $output_select_file_name open failed.");
	exit 1;
}	
my $output_itemcat_file_disc;
if (!open $output_itemcat_file_disc, ">", $output_itemcat_file_name) {
	&output_log("ERROR!!($!) $output_itemcat_file_name open failed.");
	exit 1;
}	
my $output_ydata_file_disc;
if (!open $output_ydata_file_disc, ">", $output_ydata_file_name) {
	&output_log("ERROR!!($!) $output_ydata_file_name open failed.");
	exit 1;
}	
my $output_yquantity_file_disc;
if (!open $output_yquantity_file_disc, ">", $output_yquantity_file_name) {
	&output_log("ERROR!!($!) $output_yquantity_file_name open failed.");
	exit 1;
}

####################
## 各関数間に跨って使用するグローバル変数
####################
our @global_entry_goods_supp_info=();
our @global_entry_goods_spec_info=();
our %global_entry_genre_goods_info=();
our %global_entry_parents_color_variation=();
our %global_entry_parents_size_variation=();	
our $global_category_priority=1;
our $global_entry_goods_code="";
our $global_entry_goods_category="";
our $global_entry_goods_name="";
our $global_entry_goods_price=0;
our $global_entry_goods_size="";
our $global_entry_goods_color="";
our $global_entry_goods_controlcolumn="";
our $global_entry_goods_variationflag=0;
our $global_entry_goods_rimagefilename="";
our $global_entry_goods_yimagefilename="";
our @globel_spec_sort=&get_spec_sort_from_xml();

#################################################################
##########################　main処理開始 ##########################　
#################################################################
&output_log("**********START**********\n");
# 楽天用の出力CSVファイルに項目名を出力
&add_r_csv_name();
# Yahoo!用の出力CSVファイルに項目名を出力
 &add_y_csv_name();
# 登録済みの商品をリストに入れる
my @done_5_list=();
# 商品データの作成
my $regist_mall_data_line = $input_regist_mall_data_csv->getline($input_regist_mall_data_file_disc);
while($regist_mall_data_line = $input_regist_mall_data_csv->getline($input_regist_mall_data_file_disc)){
	%global_entry_parents_color_variation=();
	%global_entry_parents_size_variation=();	
	##### regist_mall_data.csvファイルの読み出し
	# 商品コードの上位5桁を切り出し
	# goodsファイルの読み出し(項目行分1行読み飛ばし)
	seek $input_goods_file_disc,0,0;
	my $goods_line = $input_goods_csv->getline($input_goods_file_disc);
	while($goods_line = $input_goods_csv->getline($input_goods_file_disc)){
		# 登録情報から商品コード読み出し
		if (get_9code(@$regist_mall_data_line[0]) eq get_9code(@$goods_line[0])) {
			# goods.csvの商品情報を保持。コントロールカラムも保持する
			# [0]:商品管理番号 [1]:カテゴリ名 [2]:商品名 [3]:販売価格　[4]:サイズ [5]:カラー [6]:コントロールカラム [7]:バリエーションフラグ [8]:楽天店用画像ファイル名リスト [9]:ヤフー店用画像ファイル名リスト
			$global_entry_goods_code=@$regist_mall_data_line[0];
			$global_entry_goods_category=@$goods_line[1];
			$global_entry_goods_name=@$goods_line[2];
			$global_entry_goods_price=@$goods_line[3];
			$global_entry_goods_size=@$goods_line[5];
			$global_entry_goods_color=@$goods_line[6];
			$global_entry_goods_controlcolumn=@$regist_mall_data_line[7];
			$global_entry_goods_variationflag=@$regist_mall_data_line[9];
			$global_entry_goods_rimagefilename=@$regist_mall_data_line[10];
			$global_entry_goods_yimagefilename=@$regist_mall_data_line[11];
			# バリエーション商品の場合はgoods.csvに登録されているすべてのカラー、サイズのバリエーションを保持する
			if($global_entry_goods_variationflag) {
				# カラー,サイズ展開をハッシュで保持
				my $tmp_goods_csv = Text::CSV_XS->new({ binary => 1 });
				my $tmp_goods_file_disc;
				if (!open $tmp_goods_file_disc, "<", $input_goods_file_name) {
					&output_log("ERROR!!($!) $input_goods_file_name open failed.");
					exit 1;
				}
				my $tmp_goods_line = $tmp_goods_csv->getline($tmp_goods_file_disc);
				while($tmp_goods_line = $tmp_goods_csv->getline($tmp_goods_file_disc)) {	
					if (get_5code($global_entry_goods_code) eq get_5code(@$tmp_goods_line[0])) {
						# カラー情報があるものは保持する。
						my $find_flag=0;
						# 既に登録されていたら登録しない
						foreach my $key(keys(%global_entry_parents_color_variation)){
							if (&get_6_7digit(@$tmp_goods_line[0]) eq $key) {
								$find_flag=1;
								last;
							}
						}
						if (!$find_flag) {
							$global_entry_parents_color_variation{&get_6_7digit(@$tmp_goods_line[0])} = @$tmp_goods_line[6];
						}
						$find_flag=0;
						foreach my $key(keys(%global_entry_parents_size_variation)){
							if (&get_8_9digit(@$tmp_goods_line[0]) eq $key) {
								$find_flag=1;
								last;
							}
						}
						if (!$find_flag) {
							$global_entry_parents_size_variation{&get_8_9digit(@$tmp_goods_line[0])} = @$tmp_goods_line[5];
						}
					}
				}
				close($tmp_goods_file_disc);
				$tmp_goods_csv->eof;
			}
			
			foreach my $key(keys(%global_entry_parents_size_variation)){
				print "=====$global_entry_goods_code key=$key, value= $global_entry_parents_size_variation{$key}\n";
			}
			
			
			last;
		}
	}
	if ($global_entry_goods_controlcolumn eq "d") {
		#コントロールカラムdの商品の場合はdelete-item.csvの出力のみ行う
		&add_rakuten_delete_data();
		next;
	}
	
	# バリエーション商品の新規、バリエーション追加の場合は1商品しか出力しない
	my $find_flag=0;
	foreach my $code_5 (@done_5_list) {
		if ($code_5 eq get_5code($global_entry_goods_code)) {
			$find_flag=1;
			last;
		}
	}
	# 配列に値を格納
	if ($find_flag) {
		#registの次の行を読み込む
		next;
	}
	else {
		push(@done_5_list, get_5code($global_entry_goods_code));
	}
	
	if ($global_entry_goods_controlcolumn eq "u") {
		#コントロールカラムuのときは、reset-item.csvに出力
		&add_rakuten_reset_data();
	}
	##### goods_suppファイルの読み出し
	@global_entry_goods_supp_info=();
	seek $input_goods_supp_file_disc,0,0;
	my $goods_supp_line = $input_goods_supp_csv->getline($input_goods_supp_file_disc);
	while($goods_supp_line = $input_goods_supp_csv->getline($input_goods_supp_file_disc)){
		my $goods_supp_code_5 = @$goods_supp_line[0];
		# 商品コードが合致したらコードを保持する
		if (get_5code($global_entry_goods_code) eq $goods_supp_code_5) {
			# goods_supp.csvの商品情報を保持(SKUのものは一つ目に合致した商品の情報を保持)
			push(@global_entry_goods_supp_info, (@$goods_supp_line[1],@$goods_supp_line[2]));
			last;
		}
	}
	##### goods_specファイルの読み出し
	@global_entry_goods_spec_info=();
	seek $input_goods_spec_file_disc,0,0;
	my $goods_spec_line=$input_goods_spec_csv->getline($input_goods_spec_file_disc);
	while($goods_spec_line = $input_goods_spec_csv->getline($input_goods_spec_file_disc)){
		# 登録情報から商品コード読み出し
		if (get_5code($global_entry_goods_code) eq @$goods_spec_line[0]) {
			# 商品のスペック情報を保持する
			push(@global_entry_goods_spec_info, (@$goods_spec_line[1], @$goods_spec_line[2]));

		}
	}
	##### genre_goodsの読み出し
	# 商品コードの上位5桁を切り出し
	seek $input_genre_goods_file_disc,0,0;
	%global_entry_genre_goods_info=();
	# 1行読み飛ばし
	my $genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc);
	my $genre_goods_count=0;
	while($genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc)){	
		my $genre_goods_genre_code = @$genre_goods_line[0];
		my $genre_goods_goods_code = @$genre_goods_line[1];
		if ((get_5code($global_entry_goods_code) eq $genre_goods_goods_code) && (length($genre_goods_genre_code)==4)) {
			# 商品番号(SKUの場合は1商品)が合致した場合は、カテゴリ番号を保持する
			$global_entry_genre_goods_info{$genre_goods_count}=$genre_goods_genre_code;
			$genre_goods_count++;
		}
	}

	# 楽天用データを追加
#	&add_rakuten_data();
	# Yahoo!用データを追加
	&add_yahoo_data();
}

# 入力用CSVファイルモジュールの終了処理
$input_goods_csv->eof;
$input_goods_spec_csv->eof;
$input_goods_supp_csv->eof;
$input_genre_goods_csv->eof;
$input_regist_mall_data_csv->eof;
# 出力用CSVファイルモジュールの終了処理
$output_item_csv->eof;
$output_resetitem_csv->eof;
$output_deleteitem_csv->eof;
$output_select_csv->eof;
$output_itemcat_csv->eof;
$output_ydata_csv->eof;
$output_yquantity_csv->eof;
# 入力ファイルのクローズ
close $input_goods_file_disc;
close $input_goods_spec_file_disc;
close $input_goods_supp_file_disc;
close $input_genre_goods_file_disc;
close $input_regist_mall_data_file_disc;
# 出力ファイルのクローズ
close $output_item_file_disc;
close $output_resetitem_file_disc;
close $output_deleteitem_file_disc;
close $output_select_file_disc;
close $output_itemcat_file_disc;
close $output_ydata_file_disc;
close $output_yquantity_file_disc;
# 処理終了
output_log("Process is Success!!\n");
output_log("**********END**********\n");

close(LOG_FILE);
#################################################################
##########################　main処理終了 ##########################　
#################################################################

##############################
## 楽天用item.csvファイルに項目名を追加
##############################
sub add_r_itemcsv_name {
	my @csv_r_item_name=("コントロールカラム","商品管理番号（商品URL）","商品番号","全商品ディレクトリID","タグID","PC用キャッチコピー","モバイル用キャッチコピー","商品名","販売価格","表示価格","送料","商品情報レイアウト","PC用商品説明文","モバイル用商品説明文","スマートフォン用商品説明文","PC用販売説明文","商品画像URL","在庫タイプ","在庫数","在庫数表示","項目選択肢別在庫用横軸項目名","項目選択肢別在庫用縦軸項目名","在庫あり時納期管理番号","あす楽配送管理番号","再入荷お知らせボタン","ポイント変倍率","ポイント変倍率適用期間");
	my $csv_r_item_name_num=@csv_r_item_name;
	my $csv_r_item_name_count=0;
	for my $csv_r_item_name_str (@csv_r_item_name) {
		Encode::from_to( $csv_r_item_name_str, 'utf8', 'shiftjis' );
		$output_item_csv->combine($csv_r_item_name_str) or die $output_item_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_item_name_count >= $csv_r_item_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_item_file_disc $output_item_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用reset-item.csvファイルに項目名を追加
##############################
sub add_r_resetitemcsv_name {
	my @csv_r_resetitem_name=("コントロールカラム","商品管理番号（商品URL）","商品名","在庫タイプ","再入荷お知らせボタン");
	my $csv_r_resetitem_name_num=@csv_r_resetitem_name;
	my $csv_r_resetitem_name_count=0;
	for my $csv_r_resetitem_name_str (@csv_r_resetitem_name) {
		Encode::from_to( $csv_r_resetitem_name_str, 'utf8', 'shiftjis' );
		$output_resetitem_csv->combine($csv_r_resetitem_name_str) or die $output_resetitem_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_resetitem_name_count >= $csv_r_resetitem_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_resetitem_file_disc $output_resetitem_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用delete-item.csvファイルに項目名を追加
##############################
sub add_r_deleteitemcsv_name {
	my @csv_r_deleteitem_name=("コントロールカラム","商品管理番号（商品URL）","商品名");
	my $csv_r_deleteitem_name_num=@csv_r_deleteitem_name;
	my $csv_r_deleteitem_name_count=0;
	for my $csv_r_deleteitem_name_str (@csv_r_deleteitem_name) {
		Encode::from_to( $csv_r_deleteitem_name_str, 'utf8', 'shiftjis' );
		$output_deleteitem_csv->combine($csv_r_deleteitem_name_str) or die $output_deleteitem_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_deleteitem_name_count >= $csv_r_deleteitem_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_deleteitem_file_disc $output_deleteitem_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用select.csvファイルに項目名を追加
##############################
sub add_r_selectcsv_name {
	my @csv_r_select_name=("項目選択肢用コントロールカラム","商品管理番号（商品URL）","選択肢タイプ","Select/Checkbox用項目名","Select/Checkbox用選択肢","項目選択肢別在庫用横軸選択肢","項目選択肢別在庫用横軸選択肢子番号","項目選択肢別在庫用縦軸選択肢","項目選択肢別在庫用縦軸選択肢子番号","項目選択肢別在庫用取り寄せ可能表示","項目選択肢別在庫用在庫数","在庫戻しフラグ","在庫切れ時の注文受付","在庫あり時納期管理番号","在庫切れ時納期管理番号");
	my $csv_r_select_name_num=@csv_r_select_name;
	my $csv_r_select_name_count=0;
	for my $csv_r_select_name_str (@csv_r_select_name) {
		Encode::from_to( $csv_r_select_name_str, 'utf8', 'shiftjis' );
		$output_select_csv->combine($csv_r_select_name_str) or die $output_select_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_select_name_count >= $csv_r_select_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_select_file_disc $output_select_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用item-cat.csvファイルに項目名を追加
##############################
sub add_r_itemcatcsv_name {
	my @csv_r_itemcat_name=("コントロールカラム","商品管理番号（商品URL）","商品名","表示先カテゴリ","優先度","URL","1ページ複数形式");
	my $csv_r_itemcat_name_num=@csv_r_itemcat_name;
	my $csv_r_itemcat_name_count=0;
	for my $csv_r_itemcat_name_str (@csv_r_itemcat_name) {
		Encode::from_to( $csv_r_itemcat_name_str, 'utf8', 'shiftjis' );
		$output_itemcat_csv->combine($csv_r_itemcat_name_str) or die $output_itemcat_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_r_itemcat_name_count >= $csv_r_itemcat_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_itemcat_file_disc $output_itemcat_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## 楽天用ファイルに項目名を追加
##############################
sub add_r_csv_name {
	# 楽天用のitem.csvに項目名を出力
	&add_r_itemcsv_name();
	# 楽天用のreset-item.csvに項目名を出力
	&add_r_resetitemcsv_name();
	# 楽天用のdelete-item.csvに項目名を出力
	&add_r_deleteitemcsv_name();
	# 楽天用のselect.csvに項目名を出力
	&add_r_selectcsv_name();
	# 楽天用のitem-cat.csvに項目名を出力
	&add_r_itemcatcsv_name();
	return 0;
}

##############################
## Yahoo用ファイルに項目名を追加
##############################
sub add_y_csv_name {
	# Yahoo用のydata.csvに項目名を出力
	&add_y_datacsv_name();
	# Yahoo用のyquantity.csvに項目名を出力
	&add_y_quantitycsv_name();
	return 0;
}

##############################
## Yahoo用ydata.csvファイルに項目名を追加
##############################
sub add_y_datacsv_name {
	my @csv_y_data_name=("path","name","code","sub-code","original-price","price","sale-price","options","headline","caption","abstract","explanation","additional1","additional2","additional3","relevant-links","ship-weight","taxable","release-date","point-code","meta-key","meta-desc","template","sale-period-start","sale-period-end","sale-limit","sp-code","brand-code","person-code","yahoo-product-code","product-code","jan","isbn","delivery","product-category","spec1","spec2","spec3","spec4","spec5","display","astk-code");
	my $csv_y_data_name_num=@csv_y_data_name;
	my $csv_y_data_name_count=0;
	for my $csv_y_data_name_str (@csv_y_data_name) {
		$output_ydata_csv->combine($csv_y_data_name_str) or die $output_ydata_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_y_data_name_count >= $csv_y_data_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_ydata_file_disc $output_ydata_csv->string(), $post_fix_str;
	}
	return 0;
}

##############################
## Yahoo用yquantity.csvファイルに項目名を追加
##############################
sub add_y_quantitycsv_name {
	my @csv_y_quantity_name=("code","sub-code","sp-code","quantity");
	my $csv_y_quantity_name_num=@csv_y_quantity_name;
	my $csv_y_quantity_name_count=0;
	for my $csv_y_quantity_name_str (@csv_y_quantity_name) {
		$output_yquantity_csv->combine($csv_y_quantity_name_str) or die $output_yquantity_csv->error_diag();
		my $post_fix_str="";
		if (++$csv_y_quantity_name_count >= $csv_y_quantity_name_num) {
			$post_fix_str="\n";
		}
		else {
			$post_fix_str=",";
		}
		print $output_yquantity_file_disc $output_yquantity_csv->string(), $post_fix_str;
	}
	return 0;
}


##############################
## 楽天用CSVファイルにデータを追加
##############################
sub add_rakuten_data {
	# item.csvにデータを追加
	&add_rakuten_item_data();
	# select.csvにデータを追加
	&add_rakuten_select_data();
	# item-cat.csvにデータを追加
	&add_rakuten_itemcat_data();
	return 0;
}

##############################
## 楽天更新用ファイルreset-itemファイルにデータを追加
##############################
sub add_rakuten_reset_data {
	# 各値をCSVファイルに書き出す
	# コントロールカラム
	$output_resetitem_csv->combine("u") or die $output_resetitem_csv->error_diag();
	print $output_resetitem_file_disc $output_resetitem_csv->string(), ",";
	# 商品管理番号
	$output_resetitem_csv->combine(&get_5code($global_entry_goods_code)) or die $output_resetitem_csv->error_diag();
	print $output_resetitem_file_disc $output_resetitem_csv->string(), ",";
	# 商品名
	$output_resetitem_csv->combine(&create_ry_goods_name()) or die $output_resetitem_csv->error_diag();
	print $output_resetitem_file_disc $output_resetitem_csv->string(), ",";
	# 在庫タイプ
	$output_resetitem_csv->combine("0") or die $output_resetitem_csv->error_diag();
	print $output_resetitem_file_disc $output_resetitem_csv->string(), ",";
	# 再入荷お知らせボタン
	$output_resetitem_csv->combine("0") or die $output_resetitem_csv->error_diag();
	#最後に改行を追加
	print $output_resetitem_file_disc $output_resetitem_csv->string(), "\n";
	return 0;
}

##############################
## 楽天削除用ファイルdelete-itemファイルにデータを追加
##############################
sub add_rakuten_delete_data {
	# 各値をCSVファイルに書き出す
	# コントロールカラム
	$output_deleteitem_csv->combine("d") or die $output_deleteitem_csv->error_diag();
	print $output_deleteitem_file_disc $output_deleteitem_csv->string(), ",";
	# 商品管理番号
	$output_deleteitem_csv->combine($global_entry_goods_code) or die $output_deleteitem_csv->error_diag();
	print $output_deleteitem_file_disc $output_deleteitem_csv->string(), ",";
	# 商品名
	$output_deleteitem_csv->combine(&create_ry_goods_name()) or die $output_deleteitem_csv->error_diag();
	#最後に改行を追加
	print $output_deleteitem_file_disc $output_deleteitem_csv->string(), "\n";
	return 0;
}

##############################
## 楽天用item.CSVファイルにデータを追加
##############################
sub add_rakuten_item_data {
	# 各値をCSVファイルに書き出す
	# コントロールカラム
	$output_item_csv->combine($global_entry_goods_controlcolumn) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品管理番号
	my $output_code_str ="";
	if ($global_entry_goods_variationflag eq "1") {$output_code_str=&get_5code($global_entry_goods_code);}
	else {$output_code_str=&get_9code($global_entry_goods_code);}
	$output_item_csv->combine($output_code_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品番号
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 全商品ディレクトリ(手動で入力する必要がある)
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# タグID
	my $tag_id="";
	if ($global_entry_goods_size ne "") {
		# SKUの場合はサイズのtagidを出力
		$tag_id=&create_r_tag_id();
	}
	$output_item_csv->combine($tag_id) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# PC用キャッチコピー
	$output_item_csv->combine(&create_r_pccatch_copy()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# モバイル用キャッチコピー
	$output_item_csv->combine(&create_r_mbcatch_copy()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品名
	$output_item_csv->combine(&create_ry_goods_name()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 販売価格
	$output_item_csv->combine($global_entry_goods_price) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 表示価格
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 送料
	my $output_postage_str="";
	if ($global_entry_goods_price >= 5000) {$output_postage_str="1";}
	else {$output_postage_str="0";}
	$output_item_csv->combine($output_postage_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品情報レイアウト
	$output_item_csv->combine("6") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# PC用商品説明文
	$output_item_csv->combine(&create_r_pc_goods_spec) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# モバイル用商品説明文
	$output_item_csv->combine(&create_ry_mb_goods_spec) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# スマートフォン用商品説明文
	$output_item_csv->combine(&create_ry_smp_goods_spec) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# PC用販売説明文
	$output_item_csv->combine(&create_r_pc_goods_detail) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 商品画像URL
	$output_item_csv->combine(&create_r_goods_image_url) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫タイプ
	my $output_stocktype_str="";
	if ($global_entry_goods_variationflag eq "1") {$output_stocktype_str="2";}
	else {$output_stocktype_str="1";}
	$output_item_csv->combine($output_stocktype_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫数
	my $output_stocknum_str="";
	if ($global_entry_goods_variationflag eq "1") {$output_stocknum_str="";}
	else {$output_stocknum_str="0";}
	$output_item_csv->combine($output_stocknum_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫数表示
	my $output_stockdisplay_str="";
	if ($global_entry_goods_variationflag eq "1") {$output_stockdisplay_str="";}
	else {$output_stockdisplay_str="0";}
	$output_item_csv->combine($output_stockdisplay_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 項目選択肢別在庫用横軸項目名	
	$output_item_csv->combine(&create_r_lateral_name()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 項目選択肢別在庫用縦軸項目名
	my $output_stockitem_str="";
	if($global_entry_goods_variationflag ==1 ){
		#サイズ項目に値が入っていれば、サイズを出力する。
		if ($global_entry_goods_size ne "") {$output_stockitem_str="サイズ";}
		#サイズ項目が空の場合、カラーを出力。
		else {$output_stockitem_str="カラー";}
		Encode::from_to( $output_stockitem_str, 'utf8', 'shiftjis' );
	}
	$output_item_csv->combine($output_stockitem_str) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 在庫あり時納期管理番号
	my $output_stockcode_str="";
	if ($global_entry_goods_variationflag eq "1") {$output_stockcode_str="";}
	else {$output_stockcode_str="14";}
	$output_item_csv->combine($output_stockcode_str) or die $output_item_csv->error_diag();
	$output_item_csv->combine("") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# あす楽配送管理番号
	$output_item_csv->combine("1") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# 再入荷お知らせボタン
	$output_item_csv->combine("1") or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# ポイント変倍率
	$output_item_csv->combine(&create_ry_point()) or die $output_item_csv->error_diag();
	print $output_item_file_disc $output_item_csv->string(), ",";
	# ポイント変倍率適用期間
	$output_item_csv->combine(&create_r_point_term()) or die $output_item_csv->error_diag();
	#最後に改行を追加
	print $output_item_file_disc $output_item_csv->string(), "\n";
	return 0;
}

##############################
## 楽天用select.csvファイルにデータを追加
##############################
sub add_rakuten_select_data {
	# SKU(5桁)の商品のみ追加
	if ($global_entry_goods_variationflag == 1) {
		# registに登録されている5桁を含む9桁コードをgoods.csvから抽出して配列に入れる
		my $tmp_goods_file_disc;
		if (!open $tmp_goods_file_disc, "<", $input_goods_file_name) {
			&output_log("ERROR!!($!) $input_goods_file_name open failed.");
			exit 1;
		}	
		seek $tmp_goods_file_disc,0,0;
		my $find_done_flag=0;
		my $goods_line = $input_goods_csv->getline($tmp_goods_file_disc);
		while($goods_line = $input_goods_csv->getline($tmp_goods_file_disc)){
			# 登録情報から商品コード読み出し
			if (get_5code($global_entry_goods_code) eq get_5code(@$goods_line[0])) {
				# 項目選択肢用コントロールカラム
				$output_select_csv->combine("n") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 商品管理番号（商品URL）
				$output_select_csv->combine(get_5code(@$goods_line[0])) or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 選択肢タイプ
				$output_select_csv->combine("i") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# Select/Checkbox用項目名
				$output_select_csv->combine("") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# Select/Checkbox用選択肢
				$output_select_csv->combine("") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 項目選択肢別在庫用横軸選択肢
				my $size_color_var = &create_r_lateral_name();
				my $color_str = "カラー";
				Encode::from_to( $color_str, 'utf8', 'shiftjis' );
				my $size_str = "サイズ";
				Encode::from_to( $size_str, 'utf8', 'shiftjis' );
				if(@$goods_line[5] ne ""){
					if($size_color_var eq $color_str){
						$output_select_csv->combine(@$goods_line[6]) or die $output_select_csv->error_diag();
					}
					else {
						$output_select_csv->combine($size_str) or die $output_select_csv->error_diag();
					}
				}
				else{
					$output_select_csv->combine($color_str) or die $output_select_csv->error_diag();
				}
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 項目選択肢別在庫用横軸選択肢子番号
				if(@$goods_line[5] ne ""){
					my $size_color_var = &create_r_lateral_name();
					# カラーバリエーションがあってかつサイズバリエーションがある商品
					if ($size_color_var eq $color_str){
						$output_select_csv->combine(&get_6_7digit(@$goods_line[0])) or die $output_select_csv->error_diag();
					}
					else {
						$output_select_csv->combine("") or die $output_select_csv->error_diag();
					}
				}
				# カラーバリエーションがある商品
				else{
					$output_select_csv->combine("") or die $output_select_csv->error_diag();
				}
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 項目選択肢別在庫用縦軸選択肢
				if(@$goods_line[5] ne ""){
					$output_select_csv->combine(@$goods_line[5]) or die $output_select_csv->error_diag();
				}
				else{
					$output_select_csv->combine(@$goods_line[6]) or die $output_select_csv->error_diag();
				}
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 項目選択肢別在庫用縦軸選択肢子番号
				if(@$goods_line[5] ne ""){
					my $size_color_var = &create_r_lateral_name();
					# カラーバリエーションがあってかつサイズバリエーションがある商品
					my $color_str = "カラー";
					Encode::from_to( $color_str, 'utf8', 'shiftjis' );
					if ($size_color_var eq $color_str){
						$output_select_csv->combine(&get_8_9digit(@$goods_line[0])) or die $output_select_csv->error_diag();
					}
					else{
						$output_select_csv->combine(&get_4digit(@$goods_line[0])) or die $output_select_csv->error_diag();
					}
				}
				else{
					$output_select_csv->combine(&get_4digit(@$goods_line[0])) or die $output_select_csv->error_diag();
				}
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 項目選択肢別在庫用取り寄せ可能表示
				$output_select_csv->combine("") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 項目選択肢別在庫用在庫数
				$output_select_csv->combine("0") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 在庫戻しフラグ
				$output_select_csv->combine("0") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 在庫切れ時の注文受付
				$output_select_csv->combine("0") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 在庫あり時納期管理番号
				$output_select_csv->combine("14") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), ",";
				# 在庫切れ時納期管理番号
				$output_select_csv->combine("") or die $output_select_csv->error_diag();
				print $output_select_file_disc $output_select_csv->string(), "\n";

			}
		}
		close $tmp_goods_file_disc;
	}
	return 0;
}

##############################
## 楽天用item-cat.csvファイルにデータを追加
##############################
sub add_rakuten_itemcat_data {
	# 各値をファイルに出力する
	# 表示先カテゴリの出力
	if ($global_entry_goods_controlcolumn eq "n") {
		# "アイテムをチェック"
		foreach my $genre_goods_num ( sort keys %global_entry_genre_goods_info ) {
			# コントロールカラム
			$output_itemcat_csv->combine("n") or die $output_itemcat_csv->error_diag();
			print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
			# 商品管理番号（商品URL）
			if ($global_entry_goods_variationflag == 0){
			$output_itemcat_csv->combine("$global_entry_goods_code") or die $output_itemcat_csv->error_diag();
			print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		}
		else{
			$output_itemcat_csv->combine(&get_5code($global_entry_goods_code)) or die $output_itemcat_csv->error_diag();
			print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		}
		# 商品名
		$output_itemcat_csv->combine(&create_ry_goods_name()) or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 表示先カテゴリ
		chomp $global_entry_genre_goods_info{$genre_goods_num};
		$output_itemcat_csv->combine(&get_r_category_from_xml($global_entry_genre_goods_info{$genre_goods_num}, 0)) or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 優先度
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# URL
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 1ページ複数形式
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), "\n";
		}
		# "ブランドをチェック"
		# コントロールカラム
		$output_itemcat_csv->combine("n") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 商品管理番号（商品URL）
		if ($global_entry_goods_variationflag == 0){
			$output_itemcat_csv->combine("$global_entry_goods_code") or die $output_itemcat_csv->error_diag();
			print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		}
		else{
			$output_itemcat_csv->combine(&get_5code($global_entry_goods_code)) or die $output_itemcat_csv->error_diag();
			print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		}
		# 商品名
		$output_itemcat_csv->combine(&create_ry_goods_name()) or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 表示先カテゴリ
		$output_itemcat_csv->combine(&get_info_from_xml("r_category")) or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 優先度
		$output_itemcat_csv->combine("$global_category_priority") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		$global_category_priority++;
		# URL
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), ",";
		# 1ページ複数形式
		$output_itemcat_csv->combine("") or die $output_itemcat_csv->error_diag();
		print $output_itemcat_file_disc $output_itemcat_csv->string(), "\n";
		return 0;
	}
}

##############################
## Yahoo!用CSVファイルにデータを追加
##############################
sub add_yahoo_data {
	# Yahoo用のydata.csvにデータを追加
	&add_ydata_data();
	# Yahoo用のyquantity.csvにデータを追加
	&add_yquantity_data();
	
	return 0;
}

##############################
## Yahoo!用ydata.csvファイルにデータを追加
##############################
sub add_ydata_data {
	# 各値をCSVファイルに書き出す
	# path
	$output_ydata_csv->combine(&create_y_path()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# name
	$output_ydata_csv->combine(&create_ry_goods_name()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# code
	if ($global_entry_goods_variationflag == 1){
		$output_ydata_csv->combine(&get_5code($global_entry_goods_code)) or die $output_ydata_csv->error_diag();
	}
	else {
		$output_ydata_csv->combine($global_entry_goods_code) or die $output_ydata_csv->error_diag();
	}
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sub-code
	$output_ydata_csv->combine(&create_y_subcode()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# original-price
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# price
	$output_ydata_csv->combine($global_entry_goods_price) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-price
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# options
	$output_ydata_csv->combine(&create_y_options()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# headline
	$output_ydata_csv->combine(&create_y_headline()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# caption
	$output_ydata_csv->combine(&create_y_caption()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# abstract
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# explanation 
	$output_ydata_csv->combine(&create_y_explanation()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# additional1
	$output_ydata_csv->combine(&create_y_additional1()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# additional2 
	$output_ydata_csv->combine(&create_y_additional2()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# additional3
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# relevant-links
	$output_ydata_csv->combine(&create_y_relevant_links()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# ship-weight
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# taxable
	$output_ydata_csv->combine("1") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# release-date
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# point-code
	$output_ydata_csv->combine(&create_ry_point()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# meta-key
	$output_ydata_csv->combine(&create_ry_goods_name()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# meta-desc
	$output_ydata_csv->combine(&create_ry_goods_name()) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# template
	$output_ydata_csv->combine("IT02") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-period-start
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-period-end
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sale-limit
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# sp-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# brand-code(T.B.D 自動化検討)
	$output_ydata_csv->combine(&get_info_from_xml("y_brand_code")) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# person-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# yahoo-product-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# product-code
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# jan
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# isbn
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# delivery
	my $output_delivery_str="";
	if ($global_entry_goods_price >= 5000) {$output_delivery_str="1";}
	else {$output_delivery_str="0";}
	$output_ydata_csv->combine($output_delivery_str) or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# product-category(T.B.D 手動で入力)
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec1
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec2
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec3
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec4
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# spec5
	$output_ydata_csv->combine("") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# display
	$output_ydata_csv->combine("1") or die $output_ydata_csv->error_diag();
	print $output_ydata_file_disc $output_ydata_csv->string(), ",";
	# astk-code
	$output_ydata_csv->combine("2") or die $output_ydata_csv->error_diag();
	#最後に改行を追加
	print $output_ydata_file_disc $output_ydata_csv->string(), "\n";
	return 0;
}
##############################
## Yahoo!用yquantity.csvファイルにデータを追加
##############################
sub add_yquantity_data {
	if ($global_entry_goods_variationflag == 1) {
		my @subcode = ();
		@subcode = &create_y_q_subcode();
		my $subcode_count =0;
		$subcode_count = @subcode;
		foreach (my $i=1; $i<=$subcode_count-1; $i++){
		# 各値をファイルに出力する	
			# code
			$output_yquantity_csv->combine(&get_5code($global_entry_goods_code)) or die $output_yquantity_csv->error_diag();
			print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
			# sub-code
			$output_yquantity_csv->combine($subcode[$i]) or die $output_yquantity_csv->error_diag();
			print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
			# sp-code
			$output_yquantity_csv->combine("") or die $output_yquantity_csv->error_diag();
			print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
			# quantity
			$output_yquantity_csv->combine("0") or die $output_yquantity_csv->error_diag();
			print $output_yquantity_file_disc $output_yquantity_csv->string(), "\n";
		}
	}
	else {
		# code
		$output_yquantity_csv->combine($global_entry_goods_code) or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
		# sub-code
		$output_yquantity_csv->combine("") or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
		# sp-code
		$output_yquantity_csv->combine("") or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), ",";
		# quantity
		$output_yquantity_csv->combine("0") or die $output_yquantity_csv->error_diag();
		print $output_yquantity_file_disc $output_yquantity_csv->string(), "\n";
	}
	return "";
}

#########################
###楽天用データ作成関数　###
#########################

##############################
## (楽天)タグIDの生成
##############################
sub create_r_tag_id {
	my $tag_id="";
	foreach my $genre_goods_code_tmp ( sort keys %global_entry_genre_goods_info ) {
		foreach my $goods_size_code_tmp ( sort keys %global_entry_parents_size_variation ) {
			if ($tag_id ne "") {
				$tag_id .= "/";
			}
			$tag_id .= &get_r_sizetag_from_xml($global_entry_genre_goods_info{$genre_goods_code_tmp}, $global_entry_parents_size_variation{$goods_size_code_tmp});
		}
	}
	return $tag_id;
}

##############################
## (楽天)PC用キャッチコピーの生成
##############################
sub create_r_pccatch_copy {
	# キャッチコピーデータの作成
	my $catch_copy = "";
	# カテゴリが"GLOBERコレクション"の場合はXMLのbrand_name(HIGH FASHION FACTORY コレクション)に置換する
	my $str_clober_collection="GLOBERコレクション";
	Encode::from_to( $str_clober_collection, 'utf8', 'shiftjis' );
	if ($global_entry_goods_category eq $str_clober_collection) {
		$catch_copy=&get_info_from_xml("brand_name");
	}
	else {
		$catch_copy=$global_entry_goods_category;
	}
	# カテゴリ名を取得し付加する
	foreach my $genre_goods_num ( sort keys %global_entry_genre_goods_info ) {
		my $r_category_name = &get_r_category_from_xml($global_entry_genre_goods_info{$genre_goods_num}, 1);
		if ($r_category_name ne "") {
			$catch_copy .= " "."$r_category_name";
		}
	}
	# 定型文言
	my $jstr1="【レビューで商品券】【正規販売店】【代引き手数料無料】【当日お届け】";
	Encode::from_to( $jstr1, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr1";
	# 5,000円以上は送料無料の文言を付与
	if($global_entry_goods_price >= 5000) {
	  my $jstr2="【送料無料】";
	  Encode::from_to( $jstr2, 'utf8', 'shiftjis' );
	  $catch_copy .= "$jstr2";
	}
	# あす楽対応文言
	my $jstr3="【あす楽対応】";
	Encode::from_to( $jstr3, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr3";
	# 最後に改行コードを追加
	$catch_copy .= "<br>";
	return $catch_copy;
}

##############################
## (楽天)MB用キャッチコピーの生成
##############################
sub create_r_mbcatch_copy {
	# キャッチコピーデータの作成
	my $catch_copy = "";
	# カテゴリが"GLOBERコレクション"の場合はXMLのbrand_name(HIGH FASHION FACTORY コレクション)に置換する
	my $str_clober_collection="GLOBERコレクション";
	Encode::from_to( $str_clober_collection, 'utf8', 'shiftjis' );
	if ($global_entry_goods_category eq $str_clober_collection) {
		$catch_copy=&get_info_from_xml("brand_name");
	}
	else {
		$catch_copy=$global_entry_goods_category;
	}
	# 定型文言
	my $jstr1="【正規販売店】";
	Encode::from_to( $jstr1, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr1";
	# 5,000円以上は送料無料の文言を付与
	if($global_entry_goods_price >= 5000) {
	  my $jstr2="【送料無料】";
	  Encode::from_to( $jstr2, 'utf8', 'shiftjis' );
	  $catch_copy .= "$jstr2";
	}
	# あす楽対応文言は文字数制限に引っかかるので付加しない
	# あす楽対応文言
	my $jstr3="【あす楽対応】";
	Encode::from_to( $jstr3, 'utf8', 'shiftjis' );
	$catch_copy .= "$jstr3";
	return $catch_copy;
}

##############################
## (楽天)商品名の生成
##############################
sub create_ry_goods_name {
	# カテゴリ名称からブランド名を取得
	my $brand_name = &get_info_from_xml("brand_name");
	# 商品名を生成
	my $goods_name = "$brand_name".":"."$global_entry_goods_name";
	return $goods_name;
}

##############################
## (楽天)PC用説明文の生成
##############################
sub create_r_pc_goods_spec {
	# 商品説明文格納用
	my $spec_str="";

my $html_str1=
<<"HTML_STR_1";
<style type="text/css">
body { font:12px/1.5 "メイリオ",Meiryo,Osaka,"ＭＳ Ｐゴシック","MS PGothic",sans-serif; }
div, dl, dt, dd, ul, ol, li, h1, h2, h3, h4, h5, h6, object, iframe, pre, code, p, blockquote, form, fieldset, legend, table, th, td, caption, tbody, tfoot, thead {
margin: 0;
padding: 0;
}
ul, ol {list-style: none;}
table {
	border-collapse:collapse;
	border-spacing:0;
}
caption, th { text-align:left; }
.clearfix { zoom:1; }
.clearfix:after {
	display:block;
	clear:both;
	content:"";
}
a:link, a:visited {color: #362E2B;text-decoration: none;}
a:hover {text-decoration: underline;}
div.sectionInner {
	padding: 0;
	margin-bottom:18px;
	padding-bottom:68px;
	border-bottom:3px solid #000;
}
div.noteInfor {
	padding-top:30px;	
}
div.material {
	margin-bottom:30px;
	padding-top:30px;
	font-size:13px;
}
div.material dl {
	float:left;
	width:365px;
	margin-right:16px;
	border-top:1px #D9D9D9 solid;
}
div.material dl dt {
	float:left;
	width:114px;
	margin-right:5px;
	padding:7px 0 1px 17px;
	padding:5px 0 3px 17px\\9;
	color:#BA9B76;
	font-weight:bold;
}
div.material dl dd {
	padding:7px 0 1px 136px;
	padding:5px 0 3px 136px\\9;
	background:url(http://www.rakuten.ne.jp/gold/hff/img/common/line_material.gif) no-repeat 0 100%;
}
div.material dl dd:after {
	display:block;
	clear:both;
	content:"";
}
div.description {
	float:left;
	width:340px;
	background:url(http://www.rakuten.ne.jp/gold/hff/img/common/bg_dot01.gif) repeat-x 0 0;
}
div.description p {
	min-height:174px;
	padding:15px 0 22px;
	background:url(http://www.rakuten.ne.jp/gold/hff/img/common/bg_dot01.gif) repeat-x 0 100%;
	line-height:1.5;
	letter-spacing:-0.5px;
}
* html div.description p {
	min-height:174px;
}
div.description span {
	display:block;
	width:100%;
	padding:5px 0;
	background:url(http://www.rakuten.ne.jp/gold/hff/img/common/bg_dot01.gif) repeat-x 0 100%;
}
div.description span a {
	margin-left:4px;
	padding-left:12px;
	background:url(http://www.rakuten.ne.jp/gold/hff/img/common/icon_arrow01.gif) no-repeat 0 50%;	
}
table.materialDetail {
	clear:both;
	width:725px;
	margin-bottom:30px;
	border-top:2px solid #362E2B;
	border-bottom:1px solid #362E2B;
}
table.materialDetail th {
	border-bottom:1px solid #362E2B;
	font-size:12px;
	line-height:1.4;
}

.materialDetail tr.title th {
	padding:7px 0 4px 0;
}
tr.title th.pl14 {
	padding-left:14px;
}
.materialDetail td {
	font-size:12px;
	padding:5px 0 8px;
}
.materialDetail td strong {
	padding-left:26px;
}
p.campaign {
	width:723px;
	margin-bottom:30px;
	border:1px solid #C8ABA5;
}
div.textInfo {
	font-size: 13px;
	margin-bottom:30px;
	border:1px solid #D9D9D9;
}
div.textInfo ul {
	padding:17px 0 11px 24px;
}
div.textInfo ul li {
	padding:0 0 5px 5px;
	background:url(http://www.rakuten.ne.jp/gold/hff/img/common/bg_dot04.gif) no-repeat 0 40%;
}
ul.tools li {
	float:left;
	width:auto;
	padding-right:8px;
}
div.productSlide {
	padding-left:10px;
}

ul.tools a:hover img {
	opacity: 0.6;
	filter: alpha(opacity=0.6);
	-moz-opacity: 0.6;
}

ul.tools a img {
	border: none;
}

</style>
<div class="sectionInner">
<div class="noteInfor">
<p><img src="http://www.rakuten.ne.jp/gold/hff/img/detail/txt_attendtion.gif" alt="" /></p>
</div>
<!-- /.noteInfor -->
HTML_STR_1
        Encode::from_to( $html_str1, 'utf8', 'shiftjis' );
	# HTML文1を追加
	$spec_str .= "$html_str1";
	# 商品スペックは一つ目の商品のものを使用
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}

my $html_str2=
<<"HTML_STR_2";
<div class="material clearfix">
<dl>
<dt>商品番号</dt>
<dd>
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );

my $html_str3=
<<"HTML_STR_3";
</dd>
<dt>
HTML_STR_3
	Encode::from_to( $html_str3, 'utf8', 'shiftjis' );
my $html_str4=
<<"HTML_STR_4";
</dt>
<dd>
HTML_STR_4
	Encode::from_to( $html_str4, 'utf8', 'shiftjis' );
	# 商品番号を追加
	my $code ="";
	if ($global_entry_goods_variationflag ==1 ){
		$code = &get_5code($global_entry_goods_code);
	}
	else {
		$code = &get_9code($global_entry_goods_code);
		}
	$spec_str .= "$html_str2"."$code";
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		$spec_str .= "$html_str3"."$specs[$i]"."$html_str4"."$specs[$i+1]";
	}
	
my $html_str5=
<<"HTML_STR_5";
</dd>
</dl>
HTML_STR_5
	Encode::from_to( $html_str5, 'utf8', 'shiftjis' );
	$spec_str .="$html_str5";

my $html_str6=
<<"HTML_STR_6";
<div class="description">
<p>
HTML_STR_6
	Encode::from_to( $html_str6, 'utf8', 'shiftjis' );
	# 商品コメント1を追加
	my $goods_comment_1 = $global_entry_goods_supp_info[0] || "";
	my $before_rep_str0="<ul class=\"link1\">.*<\/ul>";
	my $after_rep_str0="";
	$goods_comment_1 =~ s/$before_rep_str0/$after_rep_str0/g;
	# <span>タグの削除
	my $before_rep_str1="<span class=\"itemComment\">";
	my $after_rep_str1="";
	$goods_comment_1 =~ s/$before_rep_str1/$after_rep_str1/g;
	# </span>タグの削除
	my $before_rep_str2="</span>";
	my $after_rep_str2="";
	$goods_comment_1 =~ s/$before_rep_str2/$after_rep_str2/g;
	#　消費税増税バナーを削除
	my $after_cut_exp="";
	my $before_cut_exp="<br \/><br \/><p>.*<\/p>";	
	$goods_comment_1 =~ s/$before_cut_exp/$after_cut_exp/g;	
	# 商品コメント1を追加
	$spec_str .= "$html_str6"."$goods_comment_1";
	# 5000円未満の商品は送料無料の注意書きを入れる。
	if ($global_entry_goods_price < 5000){
		my $additional_str = "<br /><br />※5,000円以上のお買い上げで送料無料";
		Encode::from_to( $additional_str, 'utf8', 'shiftjis' );
		$spec_str .= $additional_str;
	}
	# ブランド辞典を追加
	my $brand_dic = &get_info_from_xml("r_dictionary");
	if ($brand_dic ne "") {
		$spec_str .="$brand_dic";
	}
my $html_str6_2=
<<"HTML_STR_6_2";
</div>
<!-- /.description -->
</div>
<!-- /.material -->
HTML_STR_6_2
	Encode::from_to( $html_str6_2, 'utf8', 'shiftjis' );
	# タグを追加
	$spec_str .= $html_str6_2;
	#####test用
	my $test="\n";
	#####
	# 商品コメント2を取得
	my $goods_info = $global_entry_goods_supp_info[1];
	my $before_rep_str3="\n\n";
	my $after_rep_str3="\n";
	$goods_info =~ s/$before_rep_str3/$after_rep_str3/g;
	if ($goods_info ne "") {
		# 改行で分割してリストに入れる
		my $goods_info_str = "<table class=\"materialDetail f11\">\n";
		Encode::from_to( $goods_info_str, 'utf8', 'shiftjis' );
		$spec_str.= $goods_info_str;
		#####test用
		$test.=$goods_info_str;
		#####		
		my @goods_info_str_list = split(/\n/, $goods_info); 
		# リストの数を取得
		my $goods_info_str_list_count=@goods_info_str_list;
		for (my $i=1; $i < $goods_info_str_list_count-2; $i++) {
			$goods_info_str = $goods_info_str_list[$i];
			if($i==1) {
				#2行目の変換処理
				my $before_str_1="<tr><th class=\'col01\'>";
				Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
				my $before_str_2="<tr><th class=\"col01\">";
				Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
				my $after_str="<tr class=\"title\"><th class=\"bold pl14\">";	
				Encode::from_to( $after_str, 'utf8', 'shiftjis' );
				$goods_info_str =~ s/$before_str_1/$after_str/g;
				$goods_info_str =~ s/$before_str_2/$after_str/g;
				$goods_info_str.="\n";
			}
			else {
				# 3行目以降の処理
				my $before_str_1="<td class='col01'>";
				Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
				my $before_str_2="<td class=\"col01\">";
				Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
				my $after_str="<td class=\"bold\"><strong>";	
				Encode::from_to( $after_str, 'utf8', 'shiftjis' );
				$goods_info_str =~ s/$before_str_1/$after_str/g;
				$goods_info_str =~ s/$before_str_2/$after_str/g;
				# 一つ目の</td>の前に</strong>を挿入
				my $find_pos=index($goods_info_str, "</td>");
				my $find_temp_str_1=substr($goods_info_str, 0, $find_pos);
				$find_temp_str_1.="</strong>";				
				$find_temp_str_1.=substr($goods_info_str, $find_pos, length($goods_info_str)-$find_pos);
				$goods_info_str=$find_temp_str_1;
				$goods_info_str.="\n";
			}
			$spec_str.= $goods_info_str;	
			#####test用
			$test.=$goods_info_str;
			#####
		}
		# 最後から一つ前の行の処理
		$goods_info_str=$goods_info_str_list[$goods_info_str_list_count-2];	
		my $before_str_1="<tr><td class=\"col01\">";
		Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
		my $before_str_2="<tr><td class=\'col01\'>";
		Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
		my $after_str="<tr><td class=\"pb5\"><strong>";	
		Encode::from_to( $after_str, 'utf8', 'shiftjis' );
		$goods_info_str =~ s/$before_str_1/$after_str/g;
		$goods_info_str =~ s/$before_str_2/$after_str/g;
		$before_str_1="<td>";
		Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
		$after_str="<td class=\"pb5\">";	
		Encode::from_to( $after_str, 'utf8', 'shiftjis' );
		$goods_info_str =~ s/$before_str_1/$after_str/g;
		my $find_pos=index($goods_info_str, "</td>");
		my $find_temp_str_1=substr($goods_info_str, 0, $find_pos);
		$find_temp_str_1.="</strong>";				
		$find_temp_str_1.=substr($goods_info_str, $find_pos, length($goods_info_str)-$find_pos);
		$goods_info_str=$find_temp_str_1;
		$goods_info_str.="\n";	
		$spec_str.= $goods_info_str;
		# 最終行
		$goods_info_str = "</table>\n";
		Encode::from_to( $goods_info_str, 'utf8', 'shiftjis' );	
		$spec_str.= $goods_info_str;	
	}

my $html_str7=
<<"HTML_STR_7";
<div>
<p class="campaign"><img src="http://www.rakuten.ne.jp/gold/hff/img/common/bnr_campaign.jpg" alt="Special Campaign レビューを書いて商品券をGET! VJAギフトカード 5,000円分が20名様に当たる！！" /></p>
<div class="textInfo">
<ul>
<li>当店では、他店舗と在庫データを共有しているため、まれに売り切れや入荷待ちの場合がございます。</li>
<li>商品在庫についてはこちらをご覧ください。</li>
</ul>
</div>
<!-- /.textInfo -->
<ul class="tools clearfix">
<li><a href="http://www.rakuten.ne.jp/gold/hff/howto-size/index.html" class="tools01"><img src="http://www.rakuten.ne.jp/gold/hff/img/detail/btn_tool01.gif" alt="サイズの測り方" /></a></li>
<li><a href="http://www.rakuten.ne.jp/gold/hff/info/repair.html" class="tools02"><img src="http://www.rakuten.ne.jp/gold/hff/img/detail/btn_tool02.gif" alt="お直し" /></a></li>
<li><a href="http://www.rakuten.ne.jp/gold/hff/howto4.html" class="tools03"><img src="http://www.rakuten.ne.jp/gold/hff/img/detail/btn_tool03.gif" alt="返品・交換" /></a></li>
</ul>
</div>
<!-- /.sectionInner -->
HTML_STR_7
	Encode::from_to( $html_str7, 'utf8', 'shiftjis' );
	# HTML文7を追加
	$spec_str="$spec_str$html_str7";

my $html_str8=
<<"HTML_STR_8";
<br class="clear">
<table width="600" cellpadding="10" cellspacing="1" bgcolor="#eeeeee">
<tr>
<td bgcolor=#FFFFFF>
HTML_STR_8
	Encode::from_to( $html_str8, 'utf8', 'shiftjis' );

my $html_str_whc=
<<"HTML_STR_whc";
・キズのように見える白い線や表面の白い粉は、多くが表面に表れた蝋で、ブライドルレザー特有のものです。<br>
・蝋はそのままの状態で発送させていただいております。<br>
・蝋は柔らかい布で拭いたり、ブラッシングすると取れます。<br>
・天然の革製品ですので、多少のシワやキズ、色ムラなどがある場合がございます。<br>
・当店では、他店舗と在庫データを共有しているため、まれに売り切れや入荷待ちの場合がございます。<br>
<img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/title_mainte1.gif" width="600" height="63" alt="メンテナンス用品（ブライドルレザー製品）"><br>
<a href="http://item.rakuten.co.jp/hff/110621111/"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/wc_110621111.gif" width="600" height="112" alt="レザーバーム"></a><br>
  <a href="http://item.rakuten.co.jp/hff/110631111/"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/wc_110631111.gif" width="600" height="132" alt="ブライドルレザーフード"></a><br>
  <a href="http://item.rakuten.co.jp/hff/110551111/"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/wc_110551111.gif" width="600" height="112" alt="ケアブラシ"></a>
<img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/title_mainte2.gif" width="600" height="43" alt="メンテナンスの手順"><br><br>
<table width="600" border="0" cellpadding="0" cellspacing="0">
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/01.gif" alt="1" width="18" height="18"></td>
<td class="brands_copy"><span class="brands_copy">メンテナンスグッズを用意します。<br>
必要な物はブラシ、ブライドルレザーフード、レザーバーム、ウェス（布）です。<br>
テーブルを汚さないように紙も用意しておきます。</span></td>
<td width="15" align="left" class="brands_copy">&nbsp;</td>
<td width="268" align="left"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/maintenance1.jpg" width="267" height="133" alt="メンテナンスグッズ"><br>
<br></td>
</tr>
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/02.gif" alt="2" width="18" height="18"></td>
<td class="brands_copy"><span class="brands_copy">ブライドルレザーフードをほんの少し指先（または、ウェス）に取り、革に塗りこんでいきます。<br>
最初に革の目立たない場所でテストし、色の具合ををチェックして下さい。<br>
問題がないようであれば、少量のブライドルレザーフードを革の表面全体に行き渡るように、丁寧に薄く伸ばして下さい。<br>
革の成分が極端に抜けた状態の場合、塗ったそばから革に吸収され、塗った感じがしない場合があります。その時は二度塗りまたは多少多めに塗ってもよいでしょう。<br>
つけすぎた場合にはウェスなどでふき取って下さい。<br>
２トーンカラーの商品の場合、別の面に塗る際は色移りしないよう、一旦指についたブライドルレザーフードを洗い流して下さい。同じくウェスを使用する場合は新しい面をお使い下さい。</span><br>
<br>
<br></td>
<td class="brands_copy"><img src="http://www.rakuten.ne.jp/gold/hff/image/spacer.gif" alt="" width="15" height="1"></td>
<td><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/maintenance2.jpg" width="265" height="130" alt="ブライドルレザーフード"></td>
</tr>
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/03.gif" alt="3" width="18" height="18"></td>
<td class="brands_copy"><span class="brands_copy">そのままの状態で、約１時間ほど待ちます。</span></td>
<td class="brands_copy">&nbsp;</td>
<td><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/maintenance3.jpg" width="267" height="133" alt="ブライドルレザーフード"><br>
<br></td>
</tr>
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/04.gif" alt="4" width="18" height="18"></td>
<td class="brands_copy"><span class="brands_copy"> ケアブラシで、やさしく丹念にブラッシングをして下さい。</span></td>
<td class="brands_copy">&nbsp;</td>
<td><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/maintenance4.jpg" width="265" height="133" alt="ブラッシング"><br>
<br></td>
</tr>
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/05.gif" alt="5" width="18" height="18"></td>
<td class="brands_copy"><span class="brands_copy"> 左の写真はブライドルレザーフードを塗る前と後です。<br>
使用しているうちに抜けてしまった革の成分が補給され、<br>
革のボリュームが復元されたよな気がします。</span></td>
<td class="brands_copy">&nbsp;</td>
<td><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/maintenance5.jpg" width="267" height="133" alt="ブライドルレザーフードを塗る前と後"><br>
<br></td>
</tr>
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/06.gif" alt="6" width="18" height="18"></td>
<td class="brands_copy"><span class="brands_copy"> 次はつやを出すためにレザーバームを使用します。<br>
（２）と同様にレザーバームを塗りこんでいきます。</span></td>
<td class="brands_copy">&nbsp;</td>
<td><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/maintenance6.jpg" width="265" height="140" alt="レザーバーム"></td>
</tr>
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/07.gif" alt="7" width="18" height="18"></td>
<td colspan="3" class="brands_copy"><span class="brands_copy"> そのままの状態で、再び１時間ほど待ちます。 <br>
  <br>
</span></td>
</tr>
<tr align="left" valign="top">
<td width="25" align="left"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/08.gif" alt="8" width="18" height="18"></td>
<td colspan="3" align="left" class="brands_copy"><span class="brands_copy">ケアブラシで、やさしく丹念にブラッシングをして下さい。 </span><br>
  <br></td>
</tr>
<tr align="left" valign="top">
<td width="25"><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/09.gif" alt="9" width="18" height="18"></td>
<td class="brands_copy"><span class="brands_copy">写真左はブライドルレザーフードを塗った後、写真右はさらにレザーバームを塗った後です。<br>
写真では分かりにくいかもしれませんが、革に潤いとつやが出ています。<br>
革がリフレッシュするといい気分になりますね。<br>
<br>
※ブライドルレザーフードやレザーバームの見た目の効果は革の状態やメンテナンスの間隔によります。</span></td>
<td class="brands_copy">&nbsp;</td>
<td><img src="http://www.rakuten.ne.jp/gold/hff/brand/whitehouse/images/maintenance9.jpg" width="267" height="133" alt="レザーバームを塗る前と後"></td>
</tr>
</table>
HTML_STR_whc
        Encode::from_to( $html_str_whc, 'utf8', 'shiftjis' );
my $html_str_coos=
<<"HTML_STR_coos";
【ご注文にあたり、必ずお読みください】<br>
●コースは天然素材を使用し、ハンドメイドで作られているため、製造工程上、傷、シミ、汚れ、色ムラ（色の濃淡）、大きさやステッチなど仕上がりの不均一感がほとんどの商品に見られます。これらはすべてKOOSならではの独特の風合いであり、不良品ではございません。<div style="text-align:center;margin:5 auto;"><img src="http://image.rakuten.co.jp/hff/cabinet/web/2k-extra.jpg"></div>
●コースの箱は、輸入の過程で、破損、傷、汚れが生じる場合があります。また箱にマジック等での記載がある場合がございますが、不良品ではございません。<br>
※上記記載事項を理由とする返品・交換は一切お受けできませんので、ご理解いただける方のみご注文ください。<br>
●コースのサイズ感は表記サイズが同じでもデザインによって異なります。<br>
サイズチャートをご確認の上、ご注文ください。<br>
HTML_STR_coos
        Encode::from_to( $html_str_coos, 'utf8', 'shiftjis' );

my $html_str9=
<<"HTML_STR_9";
</td>
</tr>
</table>
HTML_STR_9
        Encode::from_to( $html_str9, 'utf8', 'shiftjis' );

	my $whc_str="ホワイトハウスコックス/Whitehouse Cox";
        Encode::from_to( $whc_str, 'utf8', 'shiftjis' );
	my $coos_str="コース/Koos";
        Encode::from_to( $coos_str, 'utf8', 'shiftjis' );
	
	#WHC, COOSの場合は文言追加
	if (&get_info_from_xml("brand_name") eq $whc_str){
		$spec_str="$html_str8"."$spec_str"."$html_str_whc"."$html_str9";
	}
	elsif (&get_info_from_xml("brand_name") eq $coos_str) {
		$spec_str="$html_str8"."$spec_str"."$html_str_coos"."$html_str9";
	}	

	return $spec_str;
}

##############################
## (楽天)モバイル用説明文の生成
##############################
sub create_ry_mb_goods_spec {
	my $mb_goods_spec = "";
	# 商品番号を追加
	my $str_goods_code = "商品番号";
	Encode::from_to( $str_goods_code, 'utf8', 'shiftjis' );
	my $coron="：";
	Encode::from_to( $coron, 'utf8', 'shiftjis' );
	my $slash="／";
	Encode::from_to( $slash, 'utf8', 'shiftjis' );
	my $code="";
	if ($global_entry_goods_variationflag ==1){
		$code = &get_5code($global_entry_goods_code);
	}
	else {
		$code = &get_9code($global_entry_goods_code);
	}
	$mb_goods_spec .= "$str_goods_code"."$coron"."$code"."$slash";
	# 商品スペックを追加
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		my $spec_info = $specs[$i+1];
		my $before_rep_str_spec1="<br>";
		my $after_rep_str_spec1=" ";
		$spec_info =~ s/$before_rep_str_spec1/$after_rep_str_spec1/g;
		my $before_rep_str_spec2="<br />";
		my $after_rep_str_spec2=" ";
		$spec_info =~ s/$before_rep_str_spec2/$after_rep_str_spec2/g;
		$mb_goods_spec .= "$specs[$i]"."$coron"."$spec_info";
		# 最後以外は／で区切る
		if (($i+2) < $specs_count) {
			$mb_goods_spec .= $slash;
		}
	}
my $html_str_whc=
<<"HTML_STR_whc";
キズのように見える白い線や表面の白い粉は、多くが表面に表れた蝋です。蝋は柔らかい布で拭いたり、ブラッシングすると取れます。天然の革製品ですので、多少のシワやキズ、色ムラなどがある場合がございます。
HTML_STR_whc
        Encode::from_to( $html_str_whc, 'utf8', 'shiftjis' );
my $html_str_coos=
<<"HTML_STR_coos";
※製造工程上、小さな傷、シワ、色ムラ（色の濃淡）、大きさやステッチなど仕上がりの不均一感がほとんどの商品に見られます。不良品ではございません。
HTML_STR_coos
        Encode::from_to( $html_str_coos, 'utf8', 'shiftjis' );

	my $whc_str="ホワイトハウスコックス/Whitehouse Cox";
        Encode::from_to( $whc_str, 'utf8', 'shiftjis' );
	my $coos_str="コース/Koos";
        Encode::from_to( $coos_str, 'utf8', 'shiftjis' );
	
	#WHC, COOSの場合は文言追加
	if (&get_info_from_xml("brand_name") eq $whc_str){
		$mb_goods_spec .= "<br>";
		$mb_goods_spec .= "$html_str_whc";
		$mb_goods_spec .= "<br><br>";
	}
	elsif (&get_info_from_xml("brand_name") eq $coos_str) {
		$mb_goods_spec .= "<br>";
		$mb_goods_spec .= "$html_str_coos";
		$mb_goods_spec .= "<br><br>";
	}
	# 1024byte制限チェック
	my $len = length $mb_goods_spec;
	if ($len > 1024) {
		# ログファイル出力
		my $warn = "モバイル用商品説明文がサイズ制限(1024byte)を超えています。商品番号：$global_entry_goods_code サイズ：$len(byte)";
		Encode::from_to( $warn, 'utf8', 'shiftjis' );
		&output_log("$warn\n");
	}
	return $mb_goods_spec;
}

##############################
## (楽天)スマートフォン用説明文の生成
##############################
sub create_ry_smp_goods_spec {
	my $smp_goods_spec = "";
	# 商品番号を追加
	my $str_goods_code = "商品番号";
	Encode::from_to( $str_goods_code, 'utf8', 'shiftjis' );
	my $coron="：";
	Encode::from_to( $coron, 'utf8', 'shiftjis' );
	my $slash="／";
	Encode::from_to( $slash, 'utf8', 'shiftjis' );
	my $entry_code =0;
	if ($global_entry_goods_variationflag == 1){
		$entry_code = get_5code($global_entry_goods_code);
        }
        else {
		$entry_code = get_9code($global_entry_goods_code);
        }
	$smp_goods_spec .= "$str_goods_code"."$coron"."$entry_code"."$slash";
	# 商品スペックを追加
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		my $spec_info = $specs[$i+1];
		my $before_rep_str_spec1="<br>";
		my $after_rep_str_spec1=" ";
		$spec_info =~ s/$before_rep_str_spec1/$after_rep_str_spec1/g;
		my $before_rep_str_spec2="<br />";
		my $after_rep_str_spec2=" ";
		$spec_info =~ s/$before_rep_str_spec2/$after_rep_str_spec2/g;
		$smp_goods_spec .= "$specs[$i]"."$coron"."$spec_info";
		# 最後以外は／で区切る
		if (($i+2) < $specs_count) {
			$smp_goods_spec .= $slash;
		}
	}
	# 商品コメント1を出力する。
	my $goods_comment_1 = $global_entry_goods_supp_info[0] || "";
	my $before_rep_str0="<ul class=\"link1\">.*<\/ul>";
	my $after_rep_str0="";
	$goods_comment_1 =~ s/$before_rep_str0/$after_rep_str0/g;
	# <span>タグの削除
	my $before_rep_str1="<span class=\"itemComment\">";
	my $after_rep_str1="";
	$goods_comment_1 =~ s/$before_rep_str1/$after_rep_str1/g;
	# </span>タグの削除
	my $before_rep_str2="</span>";
	my $after_rep_str2="";
	$goods_comment_1 =~ s/$before_rep_str2/$after_rep_str2/g;
	$smp_goods_spec .= "<br /><br />"."$goods_comment_1";
	# 5000円未満の商品は送料無料の注意書きを入れる。
	if ($global_entry_goods_price < 5000){
		my $additional_str = "<br /><br />※5,000円以上のお買い上げで送料無料";
		Encode::from_to( $additional_str, 'utf8', 'shiftjis' );
		$smp_goods_spec .= "$additional_str\n";
	}
my $html_str_whc=
<<"HTML_STR_whc";
<br />キズのように見える白い線や表面の白い粉は、多くが表面に表れた蝋です。蝋は柔らかい布で拭いたり、ブラッシングすると取れます。天然の革製品ですので、多少のシワやキズ、色ムラなどがある場合がございます。
HTML_STR_whc
        Encode::from_to( $html_str_whc, 'utf8', 'shiftjis' );
my $html_str_coos=
<<"HTML_STR_coos";
<br />※製造工程上、小さな傷、シワ、色ムラ（色の濃淡）、大きさやステッチなど仕上がりの不均一感がほとんどの商品に見られます。不良品ではございません。
HTML_STR_coos
        Encode::from_to( $html_str_coos, 'utf8', 'shiftjis' );

	my $whc_str="ホワイトハウスコックス/Whitehouse Cox";
        Encode::from_to( $whc_str, 'utf8', 'shiftjis' );
	my $coos_str="コース/Koos";
        Encode::from_to( $coos_str, 'utf8', 'shiftjis' );
	
	#WHC, COOSの場合は文言追加
	if (&get_info_from_xml("brand_name") eq $whc_str){
		$smp_goods_spec .= "<br>";
		$smp_goods_spec .= "$html_str_whc";
		$smp_goods_spec .= "<br><br>";
	}
	elsif (&get_info_from_xml("brand_name") eq $coos_str) {
		$smp_goods_spec .= "<br>";
		$smp_goods_spec .= "$html_str_coos";
		$smp_goods_spec .= "<br><br>";
	}
	#　※※※$smp_goods_specにすべての項目を格納し出力する。※※※
	# 商品コメント2を取得
	my $goods_info_smp = $global_entry_goods_supp_info[1] || "";
	my $before_rep_str3="\n\n";
	my $after_rep_str3="\n";
	$goods_info_smp =~ s/$before_rep_str3/$after_rep_str3/g;
	# 1行ごとにサイズ要素のみの配列を作る
	my $before_str4="<table class=\"infoTable\"><tr><td><table>";
	Encode::from_to( $before_str4, 'utf8', 'shiftjis' );
	my $after_str4="";	
	Encode::from_to( $after_str4, 'utf8', 'shiftjis' );
	$goods_info_smp =~ s/$before_str4/$after_str4/g;
	# 1行ごとにサイズ要素のみの配列を作る
	my $before_str5="<\/table><\/td><\/tr><\/table>";
	Encode::from_to( $before_str5, 'utf8', 'shiftjis' );
	my $after_str5="";	
	Encode::from_to( $after_str5, 'utf8', 'shiftjis' );
	$goods_info_smp =~ s/$before_str5/$after_str5/g;
	# サイズチャートがgoods_suppに入力されている場合
	if ($goods_info_smp ne "") {
		# スマホ用サイズチャートのヘッダー
		my $smp_sizechart_header = "<br /><br />【サイズチャート】\n" || "";
		Encode::from_to( $smp_sizechart_header, 'utf8', 'shiftjis' );
		# GLOBERのサイズチャートを改行で分割して配列にする
		my @goods_info_str_list_tr = split(/<tr>/, $goods_info_smp);
		my @goods_info_str_list_sub = split(/<\/th>/, $goods_info_str_list_tr[1]);
		# GLOBERのサイズチャートの行数を格納する
		my $goods_info_str_list_count=@goods_info_str_list_tr;
		# スマホサイズチャートを宣言
		my $smp_sizechart ="$smp_sizechart_header";
		#GLOBERのサイズチャートを<tr>の行ごとに読み込み、1行ずつ処理して変数に追加していく。
		my $i=2;
		# 1行<tr>にあたりにおけるサイズの項目数
		my $size_i=0;
		while ($i <= $goods_info_str_list_count-1){
			# 1行ごとにサイズ要素のみの配列を作る
			my $before_str1="<\/tr>";
			Encode::from_to( $before_str1, 'utf8', 'shiftjis' );
			my $after_str1="";	
			Encode::from_to( $after_str1, 'utf8', 'shiftjis' );
			$goods_info_str_list_tr[$i] =~ s/$before_str1/$after_str1/g;
			my @goods_info_str_list_size = split(/<\/td><td>/, $goods_info_str_list_tr[$i]);
			# サイズの要素数を格納する
			my $goods_info_str_list_size_count=@goods_info_str_list_size;
			# サイズ要素数が1つのとき
			if ($goods_info_str_list_size_count ==2){
				if ($size_i==0){
					my $before_str_1="<td class=\'col01\'>";
					Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
					my $before_str_2="<td class=\"col01\">";
					Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
					my $after_str="<br />";	
					Encode::from_to( $after_str, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_1/$after_str/g;
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str/g;
					$goods_info_str_list_size[$size_i] = "$goods_info_str_list_size[$size_i]";
					$smp_sizechart .= $goods_info_str_list_size[$size_i];
					$size_i++;
					next;
				}
				else {
					# サイズ項目の余計な文字列を削除
					my $before_str="<th>";
					Encode::from_to( $before_str, 'utf8', 'shiftjis' );
					my $after_str="";	
					Encode::from_to( $after_str, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str/$after_str/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\/tr>";
					Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
					my $after_str_1="";	
					Encode::from_to( $after_str_1, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/td><\/tr>";
					Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
					my $after_str_2="";	
					Encode::from_to( $after_str_2, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/td>";
					Encode::from_to( $before_str_3, 'utf8', 'shiftjis' );
					my $after_str_3="";	
					Encode::from_to( $after_str_3, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_4="<\/tr>";
					Encode::from_to( $before_str_4, 'utf8', 'shiftjis' );
					my $after_str_4="";	
					Encode::from_to( $after_str_4, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_4/$after_str_4/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "("."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]".")"."\n";
					$size_i=0;
					$i++;
				}
			}
			# サイズ要素数が2以上のとき
			else{
				# サイズ要素のみの配列を1つずつサイズの要素とサイズ項目を組み合わせてスマホ用サイズチャートを作る
				# 1番目はサイズで余分な文字列を省き、ヘッダーを追加してサイズチャートに格納する
				if ($size_i==0){
					my $before_str_1="<td class=\'col01\'>";
					Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
					my $before_str_2="<td class=\"col01\">";
					Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
					my $after_str="<br />";	
					Encode::from_to( $after_str, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_1/$after_str/g;
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str/g;
					$goods_info_str_list_size[$size_i] = "$goods_info_str_list_size[$size_i]";
					$smp_sizechart .= $goods_info_str_list_size[$size_i];
					$size_i++;
					next;
				}
				# 2番目はサイズ要素のスタートなので、（をつけて1番目のサイズ項目を組み合わせてサイズチャートに格納する
				elsif($size_i==1 ){
					# サイズ項目の余計な文字列を削除
					my $before_str="<th>";
					Encode::from_to( $before_str, 'utf8', 'shiftjis' );
					my $after_str="";	
					Encode::from_to( $after_str, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str/$after_str/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\/tr>";
					Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
					my $after_str_1="";	
					Encode::from_to( $after_str_1, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/td><\/tr>";
					Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
					my $after_str_2="";	
					Encode::from_to( $after_str_2, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/td>";
					Encode::from_to( $before_str_3, 'utf8', 'shiftjis' );
					my $after_str_3="";	
					Encode::from_to( $after_str_3, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_4="<\/tr>";
					Encode::from_to( $before_str_4, 'utf8', 'shiftjis' );
					my $after_str_4="";	
					Encode::from_to( $after_str_4, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_4/$after_str_4/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "("."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]";
					$size_i++;
					next;
				}
				elsif($size_i<$goods_info_str_list_size_count-1){
					# サイズ項目の余計な文字列を削除
					my $before_str_0="<th>";
					Encode::from_to( $before_str_0, 'utf8', 'shiftjis' );
					my $after_str_0="";	
					Encode::from_to( $after_str_0, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_0/$after_str_0/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\/tr>";
					Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
					my $after_str_1="";	
					Encode::from_to( $after_str_1, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/tr>";
					Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
					my $after_str_2="";	
					Encode::from_to( $after_str_2, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/td><\/tr>";
					Encode::from_to( $before_str_3, 'utf8', 'shiftjis' );
					my $after_str_3="";	
					Encode::from_to( $after_str_3, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "/"."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]";
					$size_i++;
					next;
				}
				else{
					# サイズ項目の余計な文字列を削除
					my $before_str_0="<th>";
					Encode::from_to( $before_str_0, 'utf8', 'shiftjis' );
					my $after_str_0="";	
					Encode::from_to( $after_str_0, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_0/$after_str_0/g;
					# サイズ項目の余計な文字列を削除
					my $before_str_1="<\tr>";
					Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
					my $after_str_1="";	
					Encode::from_to( $after_str_1, 'utf8', 'shiftjis' );
					$goods_info_str_list_sub[$size_i] =~ s/$before_str_1/$after_str_1/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_2="<\/td><\/tr>";
					Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
					my $after_str_2="";	
					Encode::from_to( $after_str_2, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_2/$after_str_2/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_3="<\/tr>";
					Encode::from_to( $before_str_3, 'utf8', 'shiftjis' );
					my $after_str_3="";	
					Encode::from_to( $after_str_3, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_3/$after_str_3/g;
					# サイズ要素の余計な文字列を削除
					my $before_str_4="<\/td>";
					Encode::from_to( $before_str_4, 'utf8', 'shiftjis' );
					my $after_str_4="";	
					Encode::from_to( $after_str_4, 'utf8', 'shiftjis' );
					$goods_info_str_list_size[$size_i] =~ s/$before_str_4/$after_str_4/g;
					chomp($goods_info_str_list_size[$size_i]);
					$smp_sizechart .= "/"."$goods_info_str_list_sub[$size_i]"."$goods_info_str_list_size[$size_i]".")"."\n";
					$size_i=0;
					$i++;
				}
			}
		}
my $html_str_end=
<<"HTML_STR_end";
<br><br>・ディスプレイにより、実物と色、イメージが異なる事がございます。あらかじめご了承ください。
<br>・当店では、他店舗と在庫データを共有しているため、まれに売り切れや入荷待ちの場合がございます。
HTML_STR_end
		Encode::from_to( $html_str_end, 'utf8', 'shiftjis' );
		$smp_sizechart .=$html_str_end;
		$smp_goods_spec .="$smp_sizechart"."\n";
=pod
			# サイズを変数に格納する
			my $smp_size_location =index($smp_sizechart,"<",5);
			# 24ならOK
			#80ならOK
			my $smp_size = substr($smp_sizechart,22,$smp_size_location-22);
			exit;
			if($i==2) {
				#3行目の変換処理
				my $before_str_1="<tr><td class=\'col01\'>";
				Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
				my $before_str_2="<tr><td class=\"col01\">";
				Encode::from_to( $before_str_2, 'utf8', 'shiftjis' );
				my $after_str="<br />";	
				Encode::from_to( $after_str, 'utf8', 'shiftjis' );
				$smp_sizechart =~ s/$before_str_1/$after_str/g;
				$smp_sizechart =~ s/$before_str_2/$after_str/g;
				my $sub_count_end=@goods_info_str_list_sub;
				for (my $sub_count=0; $sub_count < $sub_count_end-1; $sub_count++){
					my $smp_sizechart_sub = $goods_info_str_list_sub[$sub_count];
					if($sub_count==0) {
						my $before_str="<\/td><td>";
						Encode::from_to( $before_str_1, 'utf8', 'shiftjis' );
						my $after_str="("."$smp_sizechart_sub";	
						Encode::from_to( $after_str, 'utf8', 'shiftjis' );
						$smp_sizechart =~ s/$before_str_1/$after_str/g;
						$smp_sizechart =~ s/$before_str_2/$after_str/g;
				
				}

				foreach my $var(@smp_sizechart_str){
				}
				#　<td>つきの各項目の要素を配列にする
				my @smp_sizechart_list = split(/<td>/|/<\/td>/, $smp_sizechart);
				foreach my $var(@smp_sizechart_list){
				}

				#　各項目の要素のみ配列にする
				my @smp_sizechart_int = split(/<td>/, $smp_sizechart_list);
				foreach my $var(@smp_sizechart_list){
				}
=cut
				$smp_sizechart.="\n";
	}
	# 5120byte制限チェック
	my $len = length $smp_goods_spec;
	if ($len > 5120) {
		# ログファイル出力
		my $warn = "モバイル用商品説明文がサイズ制限(5120byte)を超えています。商品番号：$global_entry_goods_code サイズ：$len(byte)";
		Encode::from_to( $warn, 'utf8', 'shiftjis' );
		&output_log("$warn\n");
	}
	return $smp_goods_spec;
}

##############################
## (楽天)PC用販売説明文の生成
##############################
sub create_r_pc_goods_detail {
	my $pc_goods_detail="";
my $html_str1=
<<"HTML_STR_1";
<style type="text/css">
.headline1 {
background:url(http://www.rakuten.ne.jp/gold/hff/img/common/bg_dot01.gif) repeat-x 0 100%;
border-top:3px solid #000;
line-height:1.3;
padding:23px 0 21px 18px;
}
.headline1 span {
font-size:12px;
font-weight: normal;
color:#BA9B76;
}
/* ------------------------------------------------------------------
1-3. BoxModel styles
-------------------------------------------------------------------*/
.auto {
margin-right:auto !important;
margin-left:auto !important;
}


/* ------------------------------------------------------------------
1-4. Text styles
-------------------------------------------------------------------*/
strong, .bold { font-weight:bold; }
.italic { font-style:italic; }
.note {
margin-left:1.0em;
text-indent:-1.0em;
}
.f10 { font-size:77%; }
.f11 { font-size:85%; }
.f12 { font-size:93%; }
.f14 { font-size:108%; }
.f15 { font-size:116%; }
.f16 { font-size:123.1%; }
.f17 { font-size:131%; }
.f18 { font-size:138.5%; }
.f19 { font-size:146.5%; }
.f20 { font-size:153.9%; }
.f21 { font-size:161.6%; }
.f22 { font-size:167%; }


#detailSlide {
position:relative;
overflow:hidden;
width:740px;
height:860px;
}
#detailSlide #pd {
position:absolute;
top:10px;
left:3px;
width:740px;
height:1000px;
}
* html #detailSlide #pd {
position:absolute;
top:-188px;
height:1040px;
}
*:first-child + html #detailSlide #pd {
position:absolute;
top:-188px;
}
</style>
HTML_STR_1
        Encode::from_to( $html_str1, 'utf8', 'shiftjis' );
        chomp($html_str1);
my $html_str2=
<<"HTML_STR_2";
<h1 class="headline1 f17 bold">
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );
        chomp($html_str2);
        my $goods_name=$global_entry_goods_name."</h1>\n";
	$pc_goods_detail .= $html_str1.$html_str2.$goods_name;
my $html_str3=
<<"HTML_STR_3";
<div id="detailSlide">
<iframe src="http://www.rakuten.ne.jp/gold/_shop_3603/iframe/
HTML_STR_3
        Encode::from_to( $html_str3, 'utf8', 'shiftjis' );
        chomp($html_str3);
        # ブランド毎にiframeのhtmlの格納先を変える
        my $iframe_dir = &get_info_from_xml("r_directory");
        # 商品管理番号.htmlのファイルと連結する
        my $iframe_code = 0;
        # バリエーションがあるときは5ケタ
        if ($global_entry_goods_variationflag == 1){
		$iframe_code = get_5code($global_entry_goods_code);
        }
        # バリエーションがないときは9ケタ
        else{
		$iframe_code = get_9code($global_entry_goods_code);
        }
        my $iframe_code_str = $iframe_code.".html";
my $html_str4=
<<"HTML_STR_4";
" id="pd" frameborder="0" scrolling="no"></iframe>
</div>
HTML_STR_4
        # iframeの絶対パスを作成する
        chomp($html_str4);
        $pc_goods_detail .= $html_str3.$iframe_dir."/".$iframe_code_str.$html_str4."\n";
        &create_riframe();
	return $pc_goods_detail;
}
##############################
## (楽天)iframe.htmlの生成
##############################
sub create_riframe {
	my $iframe_html ="";
	my $info_code = ""; 
	if($global_entry_goods_variationflag == 1){
		$info_code = &get_5code($global_entry_goods_code);
	}
	else {
		$info_code = &get_9code($global_entry_goods_code);
	}
	my $brand_name = &get_info_from_xml("r_directory") || "";
	if ($brand_name eq "") {
		$brand_name = "other"
	}
	my $output_iframe_data_dir = $output_rakuten_data_dir."/iframe/".$brand_name;
	#出力先ディレクトリの作成
	unless(-d $output_iframe_data_dir) {
	# 存在しない場合はフォルダ作成
		if(!mkpath($output_iframe_data_dir)) {
			output_log("ERROR!!($!) $output_iframe_data_dir create failed.");
			exit 1;
		}
	}
	my $output_riframe_file_name="$output_iframe_data_dir"."/"."$info_code".".html";
	my $output_riframe_file_disc;
	if (!open $output_riframe_file_disc, ">", $output_riframe_file_name) {
	&output_log("ERROR!!($!) $output_riframe_file_name open failed.");
	exit 1;
	}
my $html_str1=
<<"HTML_STR_1";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja" dir="ltr">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS" />
<meta http-equiv="Content-Style-Type" content="text/css" />
<meta http-equiv="Content-Script-Type" content="text/javascript" />
<link rel="stylesheet" href="../css/style.css" media="all" />
<!--[if lte IE 7]>
<link rel="stylesheet" href="../css/ie7.css" media="all" />
<![endif]-->
<script type="text/javascript" src="../js/jquery-1.4.2.js"></script>
<script type="text/javascript" src="../js/fixHeight.js"></script>
<script type="text/javascript" src="../js/swapimage.js"></script>
<script type="text/javascript" src="../js/jquery.js"></script>
<script language="JavaScript" type="text/javascript">jQuery.noConflict();</script>
<script type="text/javascript" src="../js/lookupzip.js"></script>
<script type="text/javascript" src="../js/common.js"></script>
HTML_STR_1
        chomp($html_str1);
        # 固定のスタイルシートを追加
        $iframe_html .= $html_str1."\n";
        # 商品名のHTMLを追加
        my $iframe_goods_name = "<title>".$global_entry_goods_name."</title>";
        $iframe_html .= $iframe_goods_name."\n";
my $html_str2=
<<"HTML_STR_2";
</head>
<body id="detail">
<div id="wrapper">
<div id="contents" class="clearfix">
<div class="section clearfix">
<div class="sectionLeft">
<div class="slide">
HTML_STR_2
	chomp($html_str2);
	$iframe_html .= $html_str2."\n";
	# 画像部分のHTMLを追加する
	my $html_str_3 ="";
	# 商品画像URLとして出力する画像を配列に入れる
	my @img_url_list = split(/\//,$global_entry_goods_rimagefilename);
	# 商品画像の数を格納する
	my $img_url_list_count = @img_url_list;
	# ブランドのディレクトリを格納する
	my $img_dir = &get_info_from_xml("r_directory");
my $html_str3_1=
<<"HTML_STR_3_1";
<ul class="thumbList fixHeight clearfix">
HTML_STR_3_1
	chomp($html_str3_1);
my $html_str3_2=
<<"HTML_STR_3_2";
<li><a href="javascript:;" rev="http://image.rakuten.co.jp/_shop_3603/cabinet/pic/
HTML_STR_3_2
	chomp($html_str3_2);
my $html_str3_3=
<<"HTML_STR_3_3";
 class="swapImage">
HTML_STR_3_3
	chomp($html_str3_3);
my $html_str3_4=
<<"HTML_STR_3_4";
<img src="http://image.rakuten.co.jp/_shop_3603/cabinet/pic/
HTML_STR_3_4
	chomp($html_str3_4);
	foreach (my $i=0; $i<=$img_url_list_count-1; $i++){
		if ($i == 0){
			$iframe_html .= "<p class=\"mainImage\"><img src=\"http://image.rakuten.co.jp/_shop_3603/cabinet/pic/"."$img_dir"."/1"."/"."$img_url_list[$i]"."\""." alt=\""."$global_entry_goods_name"."\" /></p>"."\n";
			$iframe_html .= $html_str3_1."\n";
		}
		my $img_num = get_r_image_num_from_filename($img_url_list[$i]);
		# サイズバリエーションがあり、かつ、カラーバリエーションがある商品
		my $entry_img_code = &get_7code($img_url_list[$i]);
		# サイズ○カラー○、サイズ×カラー○の商品には正面画像サムネイル下に画像名を入れる
		if ($img_num == 1) {
			my $color_name ="";
			# サイズバリエーションがあり、かつ、カラーバリエーションがあるものはカラーをgoods.csvから抽出する
			if($global_entry_goods_variationflag == 1){
				my $tmp_goods_file_disc;
				if (!open $tmp_goods_file_disc, "<", $input_goods_file_name) {
					&output_log("ERROR!!($!) $input_goods_file_name open failed.");
					exit 1;
				}
				if ($global_entry_goods_size ne ""){
					$color_name = &create_r_lateral_name();
					my $color_str = "カラー";
					Encode::from_to( $color_str, 'utf8', 'shiftjis' );
					if ($color_name eq $color_str){
						# goodsファイルの読み出し(項目行分1行読み飛ばし)
						seek $tmp_goods_file_disc,0,0;
						my $goods_line = $input_goods_csv->getline($tmp_goods_file_disc);
						while($goods_line = $input_goods_csv->getline($tmp_goods_file_disc)){
							if ($entry_img_code == &get_7code(@$goods_line[0])){
								$color_name = @$goods_line[6];
								last;
							}
						}
					}
				}
				# カラーバリエーションのある商品
				else {
					# goodsファイルの読み出し(項目行分1行読み飛ばし)
					seek $tmp_goods_file_disc,0,0;
					my $goods_line = $input_goods_csv->getline($tmp_goods_file_disc);
					my $is_find_goods_info=0;
					while($goods_line = $input_goods_csv->getline($tmp_goods_file_disc)){
						if ($entry_img_code == &get_7code(@$goods_line[0])){
							$color_name = @$goods_line[6];
							last;
						}
					}
				}
				close $tmp_goods_file_disc;
			}
			# 拡大画像URLを追加
			$html_str_3 .="$html_str3_2"."$img_dir"."/"."$img_num"."/"."$img_url_list[$i]"."\""."$html_str3_3";
			# サムネイルコードを追加
			# _sをつけるためにリネームする
			my $img_url_list_file_name = substr("$img_url_list[$i]",0,9);
			my $img_file_name_thum = "$img_url_list_file_name"."s.jpg";
			$html_str_3 .="$html_str3_4"."$img_dir"."/"."$img_num"."/"."$img_file_name_thum"."\""." alt=\""."$global_entry_goods_name"."\" /></a>"."$color_name"."</li>"."\n";
		}
		else {			
			# 拡大画像URLを追加
			my $folder_image_num=$img_num;
			$html_str_3 .=$html_str3_2.$img_dir."/".$folder_image_num."/".get_r_target_image_filename($img_url_list[$i])."\"".$html_str3_3;
			# サムネイルコードを追加
			# _sをつけるためにリネームする
			my $suffix_pos = rindex(get_r_target_image_filename($img_url_list[$i]), '.');
			my $img_url_list_file_name = substr(get_r_target_image_filename($img_url_list[$i]),0,$suffix_pos);
			my $img_file_name_thum = $img_url_list_file_name."s.jpg";
			$html_str_3 .=$html_str3_4.$img_dir."/".$folder_image_num."/".$img_file_name_thum."\" alt=\"".$global_entry_goods_name."\" /></a>"."</li>"."\n";
		}
	}
	$iframe_html .= "$html_str_3"."</ul>"."\n";
my $html_str4=
<<"HTML_STR_4";
</div>
<!--/#sectionLeft--></div>
<!--/#section--></div>
<!--/#contents--></div>
<!--/#wrapper--></div>
</body>
</html>
HTML_STR_4
	chomp($html_str4);
	$iframe_html .="$html_str4";
	print $output_riframe_file_disc $iframe_html;
	close $output_riframe_file_disc;
}
##############################
## (楽天)商品画像URLの生成
##############################
sub create_r_goods_image_url {
	my $html_str1 = "http://image.rakuten.co.jp/_shop_3603/cabinet/pic/";
        chomp($html_str1);
        my $image_url_str="";
	# ブランドのディレクトリを格納する
	my $img_dir = &get_info_from_xml("r_directory");
	# 商品画像URLとして出力する画像を配列に入れる
	my @img_url_list = ();
	@img_url_list = split(/\//,$global_entry_goods_rimagefilename);
	# 商品画像の数を格納する
	my $last_count=0;
	my $img_url_list_count = @img_url_list;
	if ($img_url_list_count >= 9) {
		$last_count = 9;
	}
	else {
		$last_count = $img_url_list_count;
	}
	my $connect_str=" ";
	foreach (my $i=0; $i < $last_count; $i++){
		if ($i == $last_count) {$connect_str="";}
		my $folder_image_num=get_r_image_num_from_filename($img_url_list[$i]);
		$image_url_str .=$html_str1.$img_dir."/".$folder_image_num."/".get_r_target_image_filename($img_url_list[$i]).$connect_str;
	}
        return $image_url_str;
}

##############################
## (楽天)項目選択肢別在庫用縦軸項目名
##############################
sub create_r_lateral_name {
	my $lateral_name="";
	my $cnt_7=0;
	my $cnt_5=0;
	if ($global_entry_goods_variationflag eq "0") {
		$lateral_name="";
	}
	elsif ($global_entry_goods_size ne "") {
		my $temp_goods_file_disc;
		if (!open $temp_goods_file_disc, "<", $input_goods_file_name) {
			&output_log("ERROR!!($!) $input_goods_file_name open failed.");
			exit 1;
		}
		my $goods_line = $input_goods_csv->getline($temp_goods_file_disc);
		while($goods_line = $input_goods_csv->getline($temp_goods_file_disc)){	
			# 登録情報から商品コード読み出し
			if (get_5code($global_entry_goods_code) eq get_5code(@$goods_line[0])) {
				$cnt_5++;
			}
			if (get_7code($global_entry_goods_code) eq get_7code(@$goods_line[0])) {
				$cnt_7++;
			}
		}
		if ($cnt_5 == $cnt_7) {
			$lateral_name = " ";
		}
		else {
			my $color_str="";
			my @color_list=();
			my $var_str_count=0;
			seek $temp_goods_file_disc,0,0;
			my $goods_line = $input_goods_csv->getline($temp_goods_file_disc);
			while($goods_line = $input_goods_csv->getline($temp_goods_file_disc)){
				my $color_find=0;
				if (get_5code($global_entry_goods_code) eq get_5code(@$goods_line[0])) {
					$var_str_count++;
					foreach my $color_list_str (@color_list){
						if (@$goods_line[6] eq $color_list_str){
							$color_find = 1;
							last;
						}
					}
					if ($color_find ==1) {
						next;
					}
					else{
						my $color_str_temp = @$goods_line[6];
						push(@color_list, $color_str_temp);
						$color_str .= $color_str_temp;
					}
				}
			}
			my $len =length $color_str;
			if ($len<=94){
				$lateral_name = "カラー";
				Encode::from_to( $lateral_name, 'utf8', 'shiftjis' );
			}
			elsif ($var_str_count<=20){
				$lateral_name = " ";
			}
			else {
				$lateral_name = "カラー";
				Encode::from_to( $lateral_name, 'utf8', 'shiftjis' );
				&output_log(&get_5code($global_entry_goods_code)."you have to change color_name!!!"."\n\n");
			}
		}
	}
	else {
		$lateral_name = " ";
		Encode::from_to( $lateral_name, 'utf8', 'shiftjis' );
	}
	return $lateral_name;
}

##############################
## (楽天)ポイント変倍率
##############################
sub create_ry_point {
	# カテゴリ名称からポイント変倍率を取得
	my $brand_point = &get_info_from_xml("brand_point");
	return $brand_point;
}

##############################
## (楽天)ポイント変倍率期間
##############################
sub create_r_point_term {
	# カテゴリ名称からポイント変倍率を取得
	my $brand_point_term = &get_info_from_xml("brand_point_term");
	return $brand_point_term;
}

#########################
###Yahoo用データ作成関数　###
#########################

##############################
## (Yahoo)path情報の生成
##############################
sub create_y_path {
	# ブランド名を取得
	my $path=&get_info_from_xml("y_path");
	# クルチアーニ、ムータ、チャムス、ジョンストンズ、ベグ・スコットランドのとき、WOMEN'Sカテゴリを追加する
	my $cruciani_str = "クルチアーニ/Cruciani";
	Encode::from_to( $cruciani_str, 'utf8', 'shiftjis' );
	my $cruciani_wstr = "クルチアーニ WOMEN'S/Cruciani";
	Encode::from_to( $cruciani_wstr, 'utf8', 'shiftjis' );
	my $muta_str = "ムータ/Muta";
	Encode::from_to( $muta_str, 'utf8', 'shiftjis' );
	my $muta_wstr = "ムータ WOMEN'S/Muta";
	Encode::from_to( $muta_wstr, 'utf8', 'shiftjis' );
	my $chums_str = "チャムス/Chums";
	Encode::from_to( $chums_str, 'utf8', 'shiftjis' );
	my $chums_wstr = "チャムス WOMEN'S/Chums";
	Encode::from_to( $chums_wstr, 'utf8', 'shiftjis' );
	my $john_str = "ジョンストンズ/Johnstons";
	Encode::from_to( $john_str, 'utf8', 'shiftjis' );
	my $john_wstr = "ジョンストンズ　WOMEN'S/Johnstons";
	Encode::from_to( $john_wstr, 'utf8', 'shiftjis' );
	my $begg_str = "ベグ・スコットランド/Begg Scotland";
	Encode::from_to( $begg_str, 'utf8', 'shiftjis' );
	my $begg_wstr = "ベグ・スコットランド WOMEN'S";
	Encode::from_to( $begg_wstr, 'utf8', 'shiftjis' );
	# ハッシュの要素数をカウント
	my $global_entry_genre_count = scalar(values(%global_entry_genre_goods_info));
	foreach ( my $i = 0; $i <= $global_entry_genre_count-1; $i++) {
		my $genre_code = $global_entry_genre_goods_info{$i};
		if ($path eq $cruciani_str && $genre_code =~ /^19/ ){
			$path .= "\n"."$cruciani_wstr";
		}
		# チャムスのウェア以外(バッグ、革小物、服飾雑貨、ゴルフ)
		elsif ($path eq $chums_str && (($genre_code =~ /^1[369]/) || ($genre_code =~ /^20/))){
			$path .= "\n"."$chums_wstr";
		}
	}
	#　ムータの商品すべて
	if ($path eq $muta_str){
		$path .= "\n"."$muta_wstr";
	}
	# ジョンストンズすべて
	elsif ($path eq $john_str){
		$path .= "\n"."$john_wstr";
	}
	# ベグ・スコットランドすべて
	elsif ($path eq $begg_str){
		$path .= "\n"."$begg_wstr";
	}
	# 本店のジャンル情報からYahoo店のカテゴリ情報を取得
	# 商品コードの上位5桁を切り出し
	my $entry_goods_code_5=substr($global_entry_goods_code, 0, 5);
	seek $input_genre_goods_file_disc,0,0;
	my $genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc);
	while($genre_goods_line = $input_genre_goods_csv->getline($input_genre_goods_file_disc)){
		my $goods_code_5=@$genre_goods_line[1];
		if (($entry_goods_code_5==$goods_code_5) && (length(@$genre_goods_line[0])==4)) {
			# 表示先カテゴリ
			$path="$path"."\n".&get_y_category_from_xml(@$genre_goods_line[0]);
		}
	}
	return $path;
}

##############################
## (Yahoo)headline の生成
##############################
sub create_y_headline {
	# キャッチコピーデータの作成
	my $headline = "";
	# カテゴリが"GLOBERコレクション"の場合はXMLのbrand_name(HIGH FASHION FACTORY コレクション)に置換する
	my $str_clober_collection="GLOBERコレクション";
	Encode::from_to( $str_clober_collection, 'utf8', 'shiftjis' );
	if ($global_entry_goods_category eq $str_clober_collection) {
		$headline=&get_info_from_xml("brand_name");
	}
	else {
		$headline=$global_entry_goods_category;
	}
	#文字数制限にひっかかる為付加しない
	# カテゴリ名を取得し付加する
	foreach my $genre_goods_num ( sort keys %global_entry_genre_goods_info ) {
		my $y_category_name = &get_y_category_from_xml($global_entry_genre_goods_info{$genre_goods_num});
		if ($y_category_name ne "") {
			$headline .= " "."$y_category_name";
		}
	}
	# 定型文言
	my $jstr1="【正規販売店】";
	Encode::from_to( $jstr1, 'utf8', 'shiftjis' );
	$headline .= "$jstr1";
	# 5,000円以上は送料無料の文言を付与
	if($global_entry_goods_price >= 5000) {
		my $jstr2="【送料無料】";
		Encode::from_to( $jstr2, 'utf8', 'shiftjis' );
		$headline .= "$jstr2";
	}
	return $headline;
}

##############################
## (Yahoo)商品説明(caption)の生成
##############################
sub create_y_caption {
	# 商品説明文格納用
	my $spec_str="";
my $html_str1=
<<"HTML_STR_1";
<table width="725" style="margin:0 0 30px;border-collapse:collapse;border-spacing:0;font:12px/1.5 'メイリオ',Meiryo,Osaka,'ＭＳ Ｐゴシック','MS PGothic',sans-serif;">
<tr>
HTML_STR_1
	Encode::from_to( $html_str1, 'utf8', 'shiftjis' );
	$spec_str .=$html_str1;
	# 商品スペックは一つ目の商品のものを使用
	my @specs;
	my $spec_count = @global_entry_goods_spec_info;
	foreach my $spec_sort_num ( @globel_spec_sort ) {
		for (my $i=0; $i < $spec_count; $i+=2) {
			my $spec_num = $global_entry_goods_spec_info[$i];
			my $spec_name = &get_spec_info_from_xml($spec_num);
			my $spec_info="";
			if ($spec_num ne $spec_sort_num) {
				next;
			}
			if ($spec_num == 7) {
				# ギフトのパッケージ名を変換
				my $gift_name="GLOBERオリジナルパッケージ";
				Encode::from_to( $gift_name, 'utf8', 'shiftjis' );
				chomp $global_entry_goods_spec_info[$i+1];
				if ($global_entry_goods_spec_info[$i+1] eq $gift_name) {
					$spec_info = "当店オリジナルパッケージ";
					Encode::from_to( $spec_info, 'utf8', 'shiftjis' );
				}
				else {
					$spec_info = $global_entry_goods_spec_info[$i+1];
				}
			}
			else {
				$spec_info = $global_entry_goods_spec_info[$i+1];
				chomp $spec_info;
			}
			push(@specs, $spec_name);
			push(@specs, $spec_info);
			last;
		}
	}
my $html_str2=
<<"HTML_STR_2";
<td width="365" valign="top" style="padding:0 16px 0 0;margin:0;">
<table width="365" style="border-collapse:collapse;border-spacing:0;color: #362E2B;font:12px/1.5 'メイリオ',Meiryo,Osaka,'ＭＳ Ｐゴシック','MS PGothic',sans-serif;">
<tr>
<th align="left" valign="top" style="border-bottom:1px solid #D9D9D9;border-top:1px solid #D9D9D9;border-right:none;color:#BA9B76;font-weight:bold;padding:6px 10px 1px 16px;line-height:1.5;">商品番号</th>
HTML_STR_2
        Encode::from_to( $html_str2, 'utf8', 'shiftjis' );
	$spec_str .= "$html_str2";
my $html_str3=
<<"HTML_STR_3";
<td valign="top" width="229" style="border-bottom:1px solid #D9D9D9;border-top:1px solid #D9D9D9;border-right:none;padding:6px 0 1px 4px;line-height:1.5;">
HTML_STR_3
	Encode::from_to( $html_str3, 'utf8', 'shiftjis' );
my $html_str4=
<<"HTML_STR_4";
</td>
</tr>
HTML_STR_4
	# 商品番号を追加
	my $code ="";
	if ($global_entry_goods_variationflag ==1){
		$code =&get_5code($global_entry_goods_code)
	}
	else {
		$code =&get_9code($global_entry_goods_code)
	}
	$spec_str .= "$html_str3"."$code"."$html_str4";	
my $html_str5_1=
<<"HTML_STR_5_1";
<tr>
<th align="left" valign="top" style="border-bottom:1px solid #D9D9D9;border-right: 2px solid #FFF;color:#BA9B76;font-weight:bold;padding:6px 10px 1px 16px;line-height:1.5;">
HTML_STR_5_1

my $html_str5_2=
<<"HTML_STR_5_2";
</th>
HTML_STR_5_2

my $html_str5_3=
<<"HTML_STR_5_3";
<td valign="top" width="229" style="border-bottom:1px solid #D9D9D9;padding:6px 0 1px 4px;line-height:1.3;">
HTML_STR_5_3

my $html_str5_4=
<<"HTML_STR_5_4";
</td>
</tr>
HTML_STR_5_4
	# 商品スペックを追加
	my $specs_count = @specs;
	for (my $i=0; $i < $specs_count; $i+=2) {
		$spec_str .= "$html_str5_1"."$specs[$i]"."$html_str5_2"."\n"."$html_str5_3"."$specs[$i+1]"."$html_str5_4"."\n";
	}

my $html_str6=
<<"HTML_STR_6";
</table>
</td>
HTML_STR_6
	$spec_str .=$html_str6;

my $html_str7=
<<"HTML_STR_7";
<td valign="top" width="345" style="background:url(http://shopping.geocities.jp/hff/img/common/bg_dot01.gif) repeat-x 0 0;margin:0;padding:0;">
<p style="margin:0;padding:17px 0 16px;background:url(http://shopping.geocities.jp/hff/img/common/bg_dot01.gif) repeat-x 0 100%;color: #362E2B;line-height:1.7;letter-spacing:-0.5px;text-align:justify;">
HTML_STR_7
	Encode::from_to( $html_str7, 'utf8', 'shiftjis' );
	# 商品コメント1を追加
	my $goods_info0 = $global_entry_goods_supp_info[0];
	# <span>タグの削除
	my $before_rep_str0="<span class=\"itemComment\">";
	my $after_rep_str0="";
	$goods_info0 =~ s/$before_rep_str0/$after_rep_str0/g;
	# </span>タグの削除
	my $before_rep_str1="</span>";
	my $after_rep_str1="";
	$goods_info0 =~ s/$before_rep_str1/$after_rep_str1/g;
	#　消費税増税バナーを削除
	my $after_rep_str_2="";
	my $before_rep_str_2="</span>";	
	$goods_info0 =~ s/$before_rep_str_2/$after_rep_str_2/g;	
	$spec_str .="$html_str7"."$goods_info0";
	if ($global_entry_goods_price <= 5000){
			my $price_attention ="<br /><br />※5,000円以上のお買い上げで送料無料";
			Encode::from_to( $price_attention, 'utf8', 'shiftjis' );
			$spec_str .=$price_attention;
	}
	$spec_str .="</p>"."\n";
	my $dictionary = &get_info_from_xml("y_dictionary");
	if ($dictionary ne ""){
my $html_str8=
<<"HTML_STR_8";
<span style="display:block;width:100%;margin:0;padding:5px 0 4px;background:url(http://shopping.geocities.jp/hff/img/common/bg_dot01.gif) repeat-x 0 100%;"><a href="
HTML_STR_8
	Encode::from_to( $html_str8, 'utf8', 'shiftjis' );
my $html_str9=
<<"HTML_STR_9";
" target="_parent" style="margin-left:4px;padding-left:10px;background:url(http://shopping.geocities.jp/hff/img/common/icon_arrow01.gif) no-repeat 0 0.5em;color:#362E2B;text-decoration:none;" ="this.style.textDecoration='underline';" ="this.style.textDecoration='none';">このブランドについて</a></span></td>
HTML_STR_9
	Encode::from_to( $html_str9, 'utf8', 'shiftjis' );
	$spec_str .= "$html_str8"."$dictionary"."$html_str9";
	}
	
my $html_str10=
<<"HTML_STR_10";
</tr>
</table>
HTML_STR_10
	# HTML文6を追加
	$spec_str .="$html_str10";

	return $spec_str;
}

##############################
## (Yahoo)explanation情報の生成
##############################
sub create_y_explanation {
	my $explanation=create_ry_mb_goods_spec();
	# <br>タグは使用可能？？
	# <br>, <br />タグを半角スペースに置換
	my $before_rep_str1="<br>";
	my $before_rep_str2="<br />";
	my $after_rep_str=" ";
	$explanation =~ s/$before_rep_str1/$after_rep_str/g;
	$explanation =~ s/$before_rep_str2/$after_rep_str/g;
	# T.B.D <a>タグの削除はどうする？
	return $explanation;
}

##############################
## (Yahoo)additional1の生成
##############################
sub create_y_additional1 {
	my $additonal_1 ="";
	my $goods_info = $global_entry_goods_supp_info[1];
	# 商品コメント2がなければ何も出力しない
	if ($goods_info eq "") {
		return "";
	}
	else {
		# 商品コメント2を取得し、Yahoo用にコメント修正
		# 1行目の<table class=\"infoTable\"><tr><td><table>を削除
		my $after_rep_str1="";
		my $before_rep_str1="<table class=\"infoTable\"><tr><td><table>";
		$goods_info =~ s/$before_rep_str1/$after_rep_str1/g;
		# 最終行の</table></td></tr></table>を削除する
		my $after_rep_str2="";
		my $before_rep_str2="</table></td></tr></table>";
		$goods_info =~ s/$before_rep_str2/$after_rep_str2/g;
		# ヤフー店用のtableのヘッダー
		my $goods_info_header="<table width=\"725\" style=\"margin-bottom:24px;border-top:2px solid #362E2B;border-bottom:1px solid #362E2B;color: #362E2B;font:12px/1.5 'メイリオ',Meiryo,Osaka,'ＭＳ Ｐゴシック','MS PGotdic',sans-serif;border-collapse:collapse;border-spacing:0;\">";
		Encode::from_to( $goods_info_header, 'utf8', 'shiftjis' );
		$additonal_1 .= "$goods_info_header"."\n"."<tr>";
		#　ヤフー店用のtableのフッター
		my $goods_info_footer="</table>";
		# GLOBERのサイズチャートを改行で分割して配列にする
		my @goods_info_str_list=();
		@goods_info_str_list = split(/<tr>/, $goods_info);
		# GLOBERのサイズチャートの項目数
		my $goods_info_str_list_count = @goods_info_str_list;
		# <th>とサイズ項目を含む配列となっている
		my @goods_info_str_list_sub=();
		@goods_info_str_list_sub = split(/<\/th>/, $goods_info_str_list[1]);
		#サイズの項目数
		my $goods_info_str_list_sub_count = @goods_info_str_list_sub;
		# サイズチャートのヘッダーを作る
		my $size_header_str="<th align=\"left\" style=\"padding:7px 0 4px 14px;padding-left:14px;border-bottom:1px solid #362E2B;font-size:12px;line-height:1.4;\"><strong>";
		my $size_str="サイズ";
		Encode::from_to( $size_str, 'utf8', 'shiftjis' );
		my $size_sub_1 = "</strong></th>";
		Encode::from_to( $size_sub_1, 'utf8', 'shiftjis' );
		$additonal_1 .= "$size_header_str"."$size_str"."$size_sub_1";
		for(my $i=1; $i<=$goods_info_str_list_sub_count-2; $i++){
				my $after_rep_str3_2="<th align=\"left\" style=\"padding:7px 0 4px 0;border-bottom:1px solid #362E2B;line-height:1.4;font-weight:normal;\">";
				my $before_rep_str3_2="<th>";
				$goods_info_str_list_sub[$i] =~ s/$before_rep_str3_2/$after_rep_str3_2/g;
				$additonal_1 .= "$goods_info_str_list_sub[$i]"."</th>";
		}
		# ヘッダーの最後に改行を入れる
		$additonal_1 .="</tr>"."\n";
		# サイズチャートの中身を作る
		my $i=2;
		while($i<=$goods_info_str_list_count-1){
			$additonal_1 .="<tr>";
			# サイズチャートを</td>で分割する
			my @goods_info_str_list_td = split(/<\/td>/, $goods_info_str_list[$i]);
			# サイズチャート<td>をカウント
			my $goods_info_str_list_td = @goods_info_str_list_td;
			my $i_td =0;
			while ($i_td<=$goods_info_str_list_td-2) {
				if ($i_td ==0){
					my $after_rep_str4_1 ="<td style=\"padding:5px 0;font-size:11px;\"><strong style=\"padding-left:26px;\">";
					my $before_rep_str4_1 ="<td class=\"col01\">";
					$goods_info_str_list_td[$i_td] =~ s/$before_rep_str4_1/$after_rep_str4_1/g;
					$additonal_1 .= "$goods_info_str_list_td[$i_td]"."</strong></td>";
					$i_td++;
				}
				else {
					my $after_rep_str4_2 ="<td style=\"padding:5px 0;font-size:11px;\">";
					my $before_rep_str4_2 ="<td>";
					$goods_info_str_list_td[$i_td] =~ s/$before_rep_str4_2/$after_rep_str4_2/g;
					$additonal_1 .= "$goods_info_str_list_td[$i_td]"."</td>";
					$i_td++;
				}
			}
			$additonal_1 .="<\/tr>"."\n";
			$i++;
		}
		$additonal_1 .=$goods_info_footer;
	}
}

##############################
## (Yahoo)additional2の生成
##############################
sub create_y_additional2 {
	my $additional_2 ="";
my $html_str1_1=
<<"HTML_STR_1_1";
<iframe src="http://shopping.geocities.jp/hff/iframe/
HTML_STR_1_1
        Encode::from_to( $html_str1_1, 'utf8', 'shiftjis' );
        chomp($html_str1_1);
my $html_str1_2=
<<"HTML_STR_1_2";
.html" frameborder="0" scrolling="no" width="725" height="869"></iframe>
HTML_STR_1_2
        Encode::from_to( $html_str1_2, 'utf8', 'shiftjis' );
        chomp($html_str1_2);
my $html_str1_3=
<<"HTML_STR_1_3";
.html" frameborder="0" scrolling="no" width="725" height="160"></iframe>
HTML_STR_1_3
	Encode::from_to( $html_str1_3, 'utf8', 'shiftjis' );
        chomp($html_str1_3);
        my $code ="";
        if ($global_entry_goods_variationflag == 1) {
		$code = &get_5code($global_entry_goods_code)
        }
        else{
        	$code = $global_entry_goods_code
        }
        $additional_2 .= "$html_str1_1"."$code"."_1"."$html_str1_2"."\n";
        $additional_2 .= "$html_str1_1"."$code"."_2"."$html_str1_3";
        &create_yiframe_1();
        &create_yiframe_2();
	return $additional_2;
}

##############################
## (ヤフー)iframe_1.htmlの生成
##############################
sub create_yiframe_1 {
	my $iframe_html ="";
	my $info_code = ""; 
	if($global_entry_goods_variationflag == 1){
		$info_code = &get_5code($global_entry_goods_code);
	}
	else {
		$info_code = &get_9code($global_entry_goods_code);
	}
	my $brand_name = &get_info_from_xml("r_directory") || "";
	if ($brand_name eq "") {
		$brand_name = "other"
	}
	my $output_iframe_data_dir = $output_yahoo_data_dir."/iframe/".$brand_name;
	#出力先ディレクトリの作成
	unless(-d $output_iframe_data_dir) {
	# 存在しない場合はフォルダ作成
		if(!mkpath($output_iframe_data_dir)) {
			output_log("ERROR!!($!) $output_iframe_data_dir create failed.");
			exit 1;
		}
	}
	my $output_yiframe_file_name="$output_iframe_data_dir"."/"."$info_code"."_1".".html";
	my $output_yiframe_file_disc;
	if (!open $output_yiframe_file_disc, ">", $output_yiframe_file_name) {
	&output_log("ERROR!!($!) $output_yiframe_file_name open failed.");
	exit 1;
	}
my $html_str1=
<<"HTML_STR_1";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
<head>
<meta http-equiv="Content-Language" content="ja" />
<meta http-equiv="Content-Type" content="text/html; charset=Shift-JIS" />
<meta http-equiv="Content-Style-Type" content="text/css" />
<meta http-equiv="Content-Script-Type" content="text/javascript" />
<meta name="description" content="" />
<meta name="keywords" content="" />
<title>MEN &amp; WOMEN HIGHT FASHION FACTORY</title>
<link rel="stylesheet" type="text/css" href="../css/common.css" media="all" />
<link rel="stylesheet" type="text/css" href="../css/style.css" media="all" />
<link rel="stylesheet" type="text/css" href="../css/detail.css" media="all" />
<link rel="stylesheet" type="text/css" href="../css/print.css" media="print" />
<link rel="index contents" href="/" title="ホーム" />
<script type="text/javascript" src="../js/jquery-1.8.3.min.js"></script>
<script type="text/javascript" src="../js/common.js"></script>
<script type="text/javascript" src="../js/fixHeight.js"></script>
<script type="text/javascript" src="../js/jquery.carouFredSel-6.2.1.js"></script>
<style type="text/css">
html,body { background:none; }
ul,ol,li { margin: 0; padding: 0; }
</style>
HTML_STR_1
        chomp($html_str1);
        Encode::from_to( $html_str1, 'utf8', 'shiftjis' );
        # 固定のスタイルシートを追加
        $iframe_html .= $html_str1."\n";
my $html_str2=
<<"HTML_STR_2";
</head>
<body id="detail">
<div id="wrapper">
<div id="contents" class="clearfix">
<div class="section clearfix">
<div class="sectionLeft">
<div class="slide">
HTML_STR_2
	chomp($html_str2);
	$iframe_html .= $html_str2."\n";
	# 画像部分のHTMLを追加する
	my $html_str_3 ="";
	# 商品画像URLとして出力する画像を配列に入れる
	my @img_url_list_r = split(/\//,$global_entry_goods_rimagefilename);
	my @img_url_list_y = split(/\//,$global_entry_goods_yimagefilename);
	# 商品画像の数を格納する
	my $img_url_list_r_count = @img_url_list_r;
	my $img_url_list_y_count = @img_url_list_y;
my $html_str3_1=
<<"HTML_STR_3_1";
<div class="boxGroup">
<ul class="thumbList fixHeight clearfix" id="jcarouseItem">
HTML_STR_3_1
	chomp($html_str3_1);
	my $p_loc = index($img_url_list_y[0],".",0);
	my $img_code = substr(&get_y_target_image_filename($img_url_list_y[0]),0,$p_loc);
	$iframe_html .= "<body>"."\n"."<div class=\"slide\">"."\n"."<p class=\"mainImage\"><img src=\""."http://item.shopping.c.yimg.jp/i/f/hff_"."$img_code"."\" /></p>";
	$iframe_html .= $html_str3_1."\n";
	foreach (my $i=0; $i<=$img_url_list_y_count-1; $i++){
		my $color_name ="";
		# 楽天店に登録する画像の7桁の品番を取得する
		my $entry_img_r_code = &get_7code($img_url_list_r[$i]);
		# 楽天店に登録する画像の_nの番号を取得する
		my $img_num_r = &get_r_image_num_from_filename($img_url_list_r[$i]);
		# サイズ○カラー○、サイズ×カラー○の商品には正面画像サムネイル下に画像名を入れる
		if ($img_num_r == 1) {
			# サイズバリエーションがあり、かつ、カラーバリエーションがあるものはカラーをgoods.csvから抽出する
			if($global_entry_goods_variationflag == 1){
				my $tmp_goods_file_disc;
				if (!open $tmp_goods_file_disc, "<", $input_goods_file_name) {
					&output_log("ERROR!!($!) $input_goods_file_name open failed.");
					exit 1;
				}
				if ($global_entry_goods_size ne ""){
					my $lateral_name = &create_r_lateral_name();
					my $color_str = "カラー";
					Encode::from_to( $color_str, 'utf8', 'shiftjis' );
					if ($lateral_name eq $color_str){
						# goodsファイルの読み出し(項目行分1行読み飛ばし)
						seek $tmp_goods_file_disc,0,0;
						my $goods_line = $input_goods_csv->getline($tmp_goods_file_disc);
						while($goods_line = $input_goods_csv->getline($tmp_goods_file_disc)){
							if ($entry_img_r_code == &get_7code(@$goods_line[0])){
								$color_name = @$goods_line[6];
								last;
							}
						}
					}
				}
				# カラーバリエーションのある商品
				else {
					# goodsファイルの読み出し(項目行分1行読み飛ばし)
					seek $tmp_goods_file_disc,0,0;
					my $goods_line = $input_goods_csv->getline($tmp_goods_file_disc);
					my $is_find_goods_info=0;
					while($goods_line = $input_goods_csv->getline($tmp_goods_file_disc)){
						if ($entry_img_r_code == &get_7code(@$goods_line[0])){
							$color_name = @$goods_line[6];
							last;
						}
					}
				}
				close $tmp_goods_file_disc;
			}
		}
		# ヤフー用の登録する画像コード
		my $p_loc = index($img_url_list_y[$i],".",0);
		my $img_code = substr(&get_y_target_image_filename($img_url_list_y[$i]),0,$p_loc);
		if ($i>=0 && $i<5){
			if($color_name ne ""){
				# 拡大画像URLを追加
				$html_str_3 .="<li><a rev=\""."http://item.shopping.c.yimg.jp/i/f/hff_"."$img_code"."\" class=\"swapImage\" href=\"javascript:;\">";
				# サムネイルコードを追加
				# _sをつけるためにリネームする
				my $img_file_name_thum = "$img_code"."s.jpg";
				$html_str_3 .="<img src=\""."http://shopping.c.yimg.jp/lib/hff/"."$img_file_name_thum"."\" alt=\""."$color_name"."\" /></a><span>"."$color_name"."</span></li>"."\n";
			}
			else{
				# 拡大画像URLを追加
				$html_str_3 .="<li><a rev=\""."http://item.shopping.c.yimg.jp/i/f/hff_"."$img_code"."\" class=\"swapImage\"  href=\"javascript:;\">";
				# サムネイルコードを追加
				# _sをつけるためにリネームする
				my $img_file_name_thum = "$img_code"."s.jpg";
				$html_str_3 .="<img src=\""."http://shopping.c.yimg.jp/lib/hff/"."$img_file_name_thum"."\" /></a><span></span></li>"."\n";
			}
		}
		else {
			if ($color_name ne ""){
				# 拡大画像URLを追加
				$html_str_3 .="<li><a rev=\""."http://shopping.c.yimg.jp/lib/hff/".&get_y_target_image_filename($img_url_list_y[$i])."\" class=\"swapImage\" href=\"javascript:;\">";
				# サムネイルコードを追加
				# _sをつけるためにリネームする
				my $suffix_pos = rindex(get_y_target_image_filename($img_url_list_y[$i]), '.');
				my $img_url_list_file_name = substr(get_y_target_image_filename($img_url_list_y[$i]),0,$suffix_pos);
				my $img_file_name_thum = $img_url_list_file_name."s.jpg";
				$html_str_3 .="<img src=\""."http://shopping.c.yimg.jp/lib/hff/"."$img_file_name_thum"."\" alt=\""."$color_name"."\" /></a><span>"."$color_name"."</span></li>"."\n";
			}
			else{
				# 拡大画像URLを追加
				$html_str_3 .="<li><a rev=\""."http://shopping.c.yimg.jp/lib/hff/".&get_y_target_image_filename($img_url_list_y[$i])."\" class=\"swapImage\"  href=\"javascript:;\">";
				# サムネイルコードを追加
				# _sをつけるためにリネームする
				my $suffix_pos = rindex(get_y_target_image_filename($img_url_list_y[$i]), '.');
				my $img_url_list_file_name = substr(get_y_target_image_filename($img_url_list_y[$i]),0,$suffix_pos);
				my $img_file_name_thum = $img_url_list_file_name."s.jpg";
				$html_str_3 .="<img src=\"http://shopping.c.yimg.jp/lib/hff/"."$img_file_name_thum"."\" /></a><span></span></li>"."\n";
			}
		}
	}
	$iframe_html .= "$html_str_3"."</ul>"."\n";
my $html_str4=
<<"HTML_STR_4";
<p class="prevItem"><a href="#" class="prevItem01"><img src="../img/detail/left_arrow.gif" alt="" /></a></p>
  <p class="nextItem"><a href="#" class="nextItem01"><img src="../img/detail/right_arrow.gif" alt="" /></a></p>
 </div> 
 </div>
</body>
</html>
HTML_STR_4
	chomp($html_str4);
	$iframe_html .="$html_str4";
	print $output_yiframe_file_disc $iframe_html;
	close $output_yiframe_file_disc;
}

##############################
## (ヤフー)iframe_2.htmlの生成
##############################
sub create_yiframe_2 {
	my $iframe_html ="";
	my $info_code = ""; 
	if($global_entry_goods_variationflag == 1){
		$info_code = &get_5code($global_entry_goods_code);
	}
	else {
		$info_code = &get_9code($global_entry_goods_code);
	}
	my $brand_name = &get_info_from_xml("r_directory") || "";
	if ($brand_name eq "") {
		$brand_name = "other"
	}
	my $output_iframe_data_dir = $output_yahoo_data_dir."/iframe/".$brand_name;
	#出力先ディレクトリの作成
	unless(-d $output_iframe_data_dir) {
	# 存在しない場合はフォルダ作成
		if(!mkpath($output_iframe_data_dir)) {
			output_log("ERROR!!($!) $output_iframe_data_dir create failed.");
			exit 1;
		}
	}
	my $output_yiframe_2_file_name="$output_iframe_data_dir"."/"."$info_code"."_2".".html";
	my $output_yiframe_2_file_disc;
	if (!open $output_yiframe_2_file_disc, ">", $output_yiframe_2_file_name) {
	&output_log("ERROR!!($!) $output_yiframe_2_file_name open failed.");
	exit 1;
	}
my $html_str=
<<"HTML_STR_1";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja" lang="ja">
<head>
<meta http-equiv="Content-Language" content="ja" />
<meta http-equiv="Content-Type" content="text/html; charset=Shift-JIS" />
<meta http-equiv="Content-Style-Type" content="text/css" />
<meta http-equiv="Content-Script-Type" content="text/javascript" />
<meta name="description" content="" />
<meta name="keywords" content="" />
<title>MEN &amp; WOMEN HIGHT FASHION FACTORY</title>
<link rel="stylesheet" type="text/css" href="../css/common.css" media="all" />
<link rel="stylesheet" type="text/css" href="../css/style.css" media="all" />
<link rel="stylesheet" type="text/css" href="../css/detail.css" media="all" />
<link rel="stylesheet" type="text/css" href="../css/print.css" media="print" />
<link rel="index contents" href="/" title="ホーム" />
<style type="text/css">
html,body { background:none; }
ul,ol,li { margin: 0; padding: 0; }
</style>
</head>

<body>
 <div class="textInfo">
  <ul>
   <li>当店では、他店舗と在庫データを共有しているため、まれに売り切れや入荷待ちの場合がございます。</li>
   <li>商品在庫についてはこちらをご覧ください。</li>
  </ul>
 </div>
 <!-- /.textInfo -->
 <ul class="tools clearfix">
  <li><a href="http://store.shopping.yahoo.co.jp/hff/infosize.html" class="hover" target="_parent"><img src="../img/detail/btn_tool01.gif" alt="サイズの測り方" /></a></li>
  <li><a href="http://store.shopping.yahoo.co.jp/hff/inforepair.html" class="hover" target="_parent"><img src="../img/detail/btn_tool02.gif" alt="お直し" /></a></li>
  <li><a href="http://store.shopping.yahoo.co.jp/hff/infoexchange.html" class="hover" target="_parent"><img src="../img/detail/btn_tool03.gif" alt="返品・交換" /></a></li>
 </ul>
</body>
</html>
HTML_STR_1
        chomp($html_str);
        Encode::from_to( $html_str, 'utf8', 'shiftjis' );
	print $output_yiframe_2_file_disc $html_str;
	close $output_yiframe_2_file_disc;
}

##############################
## (Yahoo)create_y_subcodeの生成
##############################
sub create_y_subcode {
	my $subcode="";
	# バリエーション商品のみ処理
	if($global_entry_goods_variationflag) {
		my $color_str="";
		my $size_str="";		
		# カラー、サイズ共にバリエーション有の場合
		if(keys(%global_entry_parents_color_variation)>=2 && keys(%global_entry_parents_size_variation)>=2) {	
			$color_str="カラー:";
			$size_str="サイズ:";
			Encode::from_to( $color_str, 'utf8', 'shiftjis' );
			Encode::from_to( $size_str, 'utf8', 'shiftjis' );
			foreach my $color_key (sort {$a <=> $b} keys %global_entry_parents_color_variation) {
				foreach my $size_key (sort {$a <=> $b} keys %global_entry_parents_size_variation) {
					if ($subcode) {$subcode.="&";}
					my $tmp_color_str=$global_entry_parents_color_variation{$color_key};
					$tmp_color_str=~ s/\s+/_/g;
					my $tmp_size_str=$global_entry_parents_size_variation{$size_key};
					$tmp_size_str=~ s/\s+/_/g;
					$subcode .= $color_str.$tmp_color_str."#".$size_str.$tmp_size_str."=".get_5code($global_entry_goods_code).$color_key.$size_key;
				}
			}		
		}	
		elsif(keys(%global_entry_parents_color_variation)>=2 && keys(%global_entry_parents_size_variation)==1) {
			$color_str="カラー:";
			Encode::from_to( $color_str, 'utf8', 'shiftjis' );
			foreach my $color_key (sort {$a <=> $b} keys %global_entry_parents_color_variation) {
				if ($subcode) {$subcode.="&";}
				my $tmp_color_str=$global_entry_parents_color_variation{$color_key};
				$tmp_color_str=~ s/\s+/_/g;
				my $size_key=0;
				my $size=0;
				my @size_key = keys(%global_entry_parents_size_variation);
				$subcode .= $color_str.$tmp_color_str."=".get_5code($global_entry_goods_code).$color_key.$size_key[0];
			}		
		}
		elsif(keys(%global_entry_parents_color_variation)==1 && keys(%global_entry_parents_size_variation)>=2) {
			$size_str="サイズ:";
			Encode::from_to( $size_str, 'utf8', 'shiftjis' );
			foreach my $size_key (sort {$a <=> $b} keys %global_entry_parents_size_variation) {
				if ($subcode) {$subcode.="&";}
				my $tmp_size_str=$global_entry_parents_size_variation{$size_key};
				$tmp_size_str=~ s/\s+/_/g;
				my $color=0;
				my @color_key = keys (%global_entry_parents_color_variation);
				$subcode .= $size_str.$tmp_size_str."=".get_5code($global_entry_goods_code).$color_key[0].$size_key;
			}
		}
		else {
			&output_log("sub create_y_subcode() -- variation error.");
			exit 1;
		}
	}
	return $subcode;
}

##############################
## (Yahoo)create_y_optionsの生成
##############################
sub create_y_options {
	my $options="";
	# バリエーション商品のみ処理
	if($global_entry_goods_variationflag) {
		my $color_str="";
		my $size_str="";		
		# カラー、サイズ共にバリエーション有の場合
		if(keys(%global_entry_parents_color_variation)>=2) {
			$color_str="カラー|175|";
			Encode::from_to( $color_str, 'utf8', 'shiftjis' );
			foreach my $color_key (sort {$a <=> $b} keys %global_entry_parents_color_variation) {
				# " "がある場合は"_"に置換
				my $tmp_str=$global_entry_parents_color_variation{$color_key};
				$tmp_str=~ s/\s+/_/g;
				$color_str .= " ".$tmp_str;
			}
			$options .= $color_str;
		}
		if(keys(%global_entry_parents_size_variation)>=2) {
			$size_str="サイズ|178|";
			Encode::from_to( $size_str, 'utf8', 'shiftjis' );
			if ($options) {$options.="\n\n";}
			foreach my $size_key (sort {$a <=> $b} keys %global_entry_parents_size_variation) {
				# サイズの中に" "がある場合は"_"に置換
				my $tmp_str=$global_entry_parents_size_variation{$size_key};
				$tmp_str=~ s/\s+/_/g;
				$size_str .= " ".$tmp_str;
			}
			$options.=$size_str;
		}
	}
	return $options;
}

##############################
## (Yahoo)relevant-linksの生成
##############################
sub create_y_relevant_links {
	# 登録商品番号を保持
	my @regist_item_list=();
	my $tmp_regist_mall_data_csv = Text::CSV_XS->new({ binary => 1 });
	my $tmp_regist_mall_data_file_disc;
	if (!open $tmp_regist_mall_data_file_disc, "<", $input_regist_mall_data_file_name) {
		&output_log("ERROR!!($!) $input_regist_mall_data_file_name open failed.");
		exit 1;
	}
	my $tmp_regist_mall_data_line = $tmp_regist_mall_data_csv->getline($tmp_regist_mall_data_file_disc);
	while($tmp_regist_mall_data_line = $tmp_regist_mall_data_csv->getline($tmp_regist_mall_data_file_disc)) {
		push(@regist_item_list, @$tmp_regist_mall_data_line[0]);
	}
	close($tmp_regist_mall_data_file_disc);
	$tmp_regist_mall_data_csv->eof;
	# 登録する商品の次の商品番号を5つ登録する
	my $relevant_links_str="";
	my $item_list_num=@regist_item_list;
	my $item_list_count=0;
	for (my $i=0; $i<$item_list_num; $i++) {
		if ($global_entry_goods_code eq $regist_item_list[$i]) {
			my $relevant_num=0;
			my $relevant_num_max=0;
			if ($item_list_num > 5) {
				$relevant_num_max=6;
			}
			else {
				$relevant_num_max=$item_list_num;
			}
			for (my $y=1; $y<$relevant_num_max; $y++) {
				if (($i+$y) >= $item_list_num) {
					$relevant_num=($i+$y)-$item_list_num;
				}
				else {
					$relevant_num=$i+$y;
				}
				if ($relevant_links_str ne "") {
					$relevant_links_str .= " ";
				}
				$relevant_links_str .= $relevant_links_str.$regist_item_list[$relevant_num];
			}
		}
	}
	return $relevant_links_str;
}
##############################
## (Yahoo)y_quatityの生成
##############################
sub create_y_q_subcode {
	my @subcode="";
	# バリエーション商品のみ処理
	if($global_entry_goods_variationflag) {
		my $color_str="";
		my $size_str="";
		my $subcode="";		
		# カラー、サイズ共にバリエーション有の場合
		if(keys(%global_entry_parents_color_variation)>=2 && keys(%global_entry_parents_size_variation)>=2) {	
			foreach my $color_key (sort {$a <=> $b} keys %global_entry_parents_color_variation) {
				foreach my $size_key (sort {$a <=> $b} keys %global_entry_parents_size_variation) {
					$subcode = get_5code($global_entry_goods_code).$color_key.$size_key;
					push (@subcode,$subcode);
				}
			}		
		}	
		elsif(keys(%global_entry_parents_color_variation)>=2 && keys(%global_entry_parents_size_variation)==1) {
			foreach my $color_key (sort {$a <=> $b} keys %global_entry_parents_color_variation) {
				my @size_key = keys(%global_entry_parents_size_variation);
				$subcode = get_5code($global_entry_goods_code).$color_key.$size_key[0];
				push (@subcode,$subcode);
			}		
		}
		elsif(keys(%global_entry_parents_color_variation)==1 && keys(%global_entry_parents_size_variation)>=2) {
			foreach my $size_key (sort {$a <=> $b} keys %global_entry_parents_size_variation) {
				my @color_key = keys (%global_entry_parents_color_variation);
				my @size_key = keys (%global_entry_parents_size_variation);
				$subcode = get_5code($global_entry_goods_code).$color_key[0].$size_key;
				push (@subcode,$subcode);
			}
		}
		else {
			&output_log("sub create_y_subcode() -- variation error.");
			exit 1;
		}
		print "!!!!!!!!!!!!!!!$subcode[0]/n/n/n/n";
		return @subcode;	
	}
	else {
		return "";
	}
	
}

#####################
### ユーティリティ関数　###
#####################
## 指定されたカテゴリ名に対応するカテゴリをXMLファイルから取得する
sub get_info_from_xml {
	my $info_name = $_[0]; 
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
		my $goods_info_category=$global_entry_goods_category;
		# カテゴリ名のチェック
		if ($goods_info_category eq $xml_category_name){
			$info = $xml_data->{brand}[$count]->{$info_name};
			Encode::_utf8_off($info);
			Encode::from_to( $info, 'utf8', 'shiftjis' );
			last;
		}
		$count++;
	}
	return $info;
}

## スペック情報のソート順を取得する
sub get_spec_sort_from_xml {
	#brand.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$goods_spec_xml_filename",ForceArray=>['spec']);
	# XMLからカテゴリを取得し、ハッシュに一時的に保持する
	my $count=0;
	my $info="";
	my %temp_spec_sort;
	while(1) {
		my $xml_spec_sort_num = $xml_data->{spec}[$count]->{spec_sort_num};
		my $xml_spec_number = $xml_data->{spec}[$count]->{spec_number};
		if (!$xml_spec_sort_num) {
			# 情報を取得できなかったら終了
			last;
		}
		$temp_spec_sort{$xml_spec_sort_num}=$xml_spec_number;
		$count++;
	}	
	# スペック情報のソート順を配列変数に格納する
	my @spec_sort;
	foreach my $key ( sort { $a <=> $b } keys %temp_spec_sort ) { 
		push(@spec_sort, $temp_spec_sort{$key});
	}
	return @spec_sort;
}

## 指定されたスペック番号に対応するスペック名をXMLファイルから取得する
sub get_spec_info_from_xml {
	my $spec_number = $_[0]; 
	#brand.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$goods_spec_xml_filename",ForceArray=>['spec']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_spec_number = $xml_data->{spec}[$count]->{spec_number};
		Encode::_utf8_off($xml_spec_number);
		Encode::from_to( $xml_spec_number, 'utf8', 'shiftjis' );
		$info = $xml_data->{spec}[$count]->{spec_name};
		if (!$info) {
			# 情報を取得できなかったので、終了
			output_log("not exist spec_number($spec_number) in $goods_spec_xml_filename\n");
			last;
		}
		Encode::_utf8_off($info);
		Encode::from_to( $info, 'utf8', 'shiftjis' );
		if ($spec_number == $xml_spec_number){
			last;
		}
		$count++;
	}
	return $info;
}

## 指定されたスサイズに対応するサイズタグ情報をXMLファイルから取得する
sub get_r_sizetag_from_xml {
	my $category_num = $_[0]; 
	my $size = $_[1]; 
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$r_size_tag_xml_filename",ForceArray=>['category_size']);
	# XMLからカテゴリを取得
	my $category_size_count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ番号を取得
		my $xml_g_category_num = $xml_data->{category_size}[$category_size_count]->{g_category_num};
		if (!$xml_g_category_num) {
			# 情報を取得できなかったので終了
			last;
		}
		Encode::_utf8_off($xml_g_category_num);
		Encode::from_to( $xml_g_category_num, 'utf8', 'shiftjis' );
		my $xml_g_size = $xml_data->{category_size}[$category_size_count]->{g_size};
		Encode::_utf8_off($xml_g_size);
		Encode::from_to( $xml_g_size, 'utf8', 'shiftjis' );
		my $is_end=0;
		if (($xml_g_category_num eq $category_num) && ($xml_g_size eq $size)) {
			# カテゴリ番号とサイズが合致した場合はサイズタグを取得する
			$info=$xml_data->{category_size}[$category_size_count]->{r_size_tag};
			if (!$info) {
				# 情報を取得できなかった
				output_log("not exist r_size_tag(category_num:$category_num  size:$size) in $r_size_tag_xml_filename\n");
			}
			# 曖昧なサイズだったらその旨ログに出力する
			if ($xml_data->{category_size}[$category_size_count]->{confusion}) {
				output_log("Rakuten sizetag confusion!! [$global_entry_goods_code] size:$size\n");
			}
			last;
		}
		$category_size_count++;
	}
	return $info;
}

## 指定されたGLOBERのカテゴリ番号に対応する楽天のカテゴリ名をXMLファイルから取得する
## arg1=GLOBERのカテゴリ番号　　arg2=商品ページに表示する文言取得は0, カテゴリ名取得は1
sub get_r_category_from_xml {
#	my $category_number = 0;	
	my $category_number = $_[0];
	my $category_disp_type = $_[1];
	#category.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$category_xml_filename",ForceArray=>['category']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_category_number = 0;
		$xml_category_number = $xml_data->{category}[$count]->{g_category_num} || "";
		if (!$xml_category_number) {
			# 情報を取得できなかったので、終了
			output_log("not exist xml_category_number(".$xml_category_number.") in ".$category_xml_filename."\n");
			last;
		}
		Encode::_utf8_off($xml_category_number);
		Encode::from_to( $xml_category_number, 'utf8', 'shiftjis' );
		# カテゴリ名のチェック
		if ($category_number eq $xml_category_number){
			$info = $xml_data->{category}[$count]->{r_category_name};
			Encode::_utf8_off($info);
			Encode::from_to( $info, 'utf8', 'shiftjis' );
			last;
		}
		$count++;
	}
	if ($category_disp_type == 1) {
		# カテゴリ名取得の場合は'\'の後ろのカテゴリ名のみにする
		$info = substr($info, index($info, "\\")+1);
	}
	return $info;
}

## 指定されたGLOBERのカテゴリ番号に対応するYahooのカテゴリ名をXMLファイルから取得する
sub get_y_category_from_xml {
	my $category_number = $_[0]; 
	#category.xmlからブランド名を取得
	my $xml = XML::Simple->new;
	# XMLファイルのパース
	my $xml_data = $xml->XMLin("$category_xml_filename",ForceArray=>['category']);
	# XMLからカテゴリを取得
	my $count=0;
	my $info="";
	while(1) {
		# XMLからカテゴリ名を取得
		my $xml_category_number = $xml_data->{category}[$count]->{g_category_num};
		if (!$xml_category_number) {
			# 情報を取得できなかったので、終了
			output_log("not exist xml_category_number($xml_category_number) in $category_xml_filename\n");
			last;
		}
		Encode::_utf8_off($xml_category_number);
		Encode::from_to( $xml_category_number, 'utf8', 'shiftjis' );
		# カテゴリ名のチェック
		if ($category_number == $xml_category_number){
			$info = $xml_data->{category}[$count]->{y_category_name};
			Encode::_utf8_off($info);
			Encode::from_to( $info, 'utf8', 'shiftjis' );
			last;
		}
		$count++;
	}
	return $info;
}

## ログ出力
sub output_log {
	my $day=&to_YYYYMMDD_string();
	print "[$day]:$_[0]";
	print LOG_FILE "[$day]:$_[0]";
}

## 現在日時取得関数
sub to_YYYYMMDD_string {
  my $time = time();
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
  my $result = sprintf("%04d%02d%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
  return $result;
}

sub delete_double_quotation {
	my $str = $_[0] || ""; 
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

sub get_9code {
	return substr(delete_double_quotation($_[0]), 0, 9);
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

sub get_4digit {
	return substr(delete_double_quotation($_[0]), 5, 4);
}

sub get_6_7digit {
	return substr(delete_double_quotation($_[0]), 5, 2);
}

sub get_8_9digit {
	return substr(delete_double_quotation($_[0]), 7, 2);
}

sub get_r_target_image_filename {
	my $file_name=$_[0];
	# "_n"までのファイル名を保持
	my $temp_file_name_1=substr($file_name, 0, 7);
	my $temp_file_name_2=substr($file_name, 8+get_image_numdigit_from_filename($file_name, 7), 4);
	# ファイル番号からprefixを判断
	my $file_count=get_r_image_num_from_filename($file_name) || 0;
	my $target_image_prefix = "";
	if ($file_count < 9) {
		$target_image_prefix = "_";
	}			
	elsif ($file_count >= 9 && $file_count <= 16) {
		$target_image_prefix = "_a_"
	}
	elsif ($file_count >= 17 && $file_count <= 24) {
		$target_image_prefix = "_b_"
	}
	elsif ($file_count >= 25 && $file_count <= 32) {
		$target_image_prefix = "_c_"
	}
	else {
		#エラー ログ出力
		exit 1;
	}
	my $temp_num=$file_count%8;
	if (!$temp_num) {$temp_num=8;}
	return $temp_file_name_1.$target_image_prefix.$temp_num.$temp_file_name_2;
}

sub get_r_image_num_from_filename {
	return substr($_[0], 8, get_image_numdigit_from_filename($_[0], 7));
}

# ヤフー用ファイル
sub get_y_target_image_filename {
	my $file_name=$_[0];
	# "_n"までのファイル名を保持
	my $temp_file_name_1="";
	my $goods_code_digit = 0;
	if ($global_entry_goods_variationflag ==1){
		$goods_code_digit=5;
		$temp_file_name_1=substr($file_name, 0, $goods_code_digit);
	}
	else {
		$goods_code_digit=9;
		$temp_file_name_1=substr($file_name, 0, $goods_code_digit);
	}
	my $temp_file_name_len=length($temp_file_name_1)+1;
	my $temp_file_name_2=substr($file_name, $temp_file_name_len+get_image_numdigit_from_filename($file_name, $goods_code_digit), 4);
	# ファイル番号からprefixを判断
	my $file_count=get_y_image_num_from_filename($file_name);
	my $target_image_prefix = "";
	my $temp_num="";
	if ($file_count){
		if ($file_count < 9) {
			$target_image_prefix = "_";
		}			
		elsif ($file_count >= 9 && $file_count <= 16) {
print "-----file_count ~= $file_count\n";
			$target_image_prefix = "_a_"
		}
		elsif ($file_count >= 17 && $file_count <= 24) {
			$target_image_prefix = "_b_"
		}
		elsif ($file_count >= 25 && $file_count <= 32) {
			$target_image_prefix = "_c_"
		}
		else {
			#エラー ログ出力
			exit 1;
		}
		$temp_num=$file_count%8;
		if (!$temp_num) {$temp_num=8;}
	}
	if ($file_count >= 9 && $file_count <= 16) {
print "#####$temp_file_name_1$target_image_prefix$temp_num$temp_file_name_2\n";
		}
	my $y_file_name = "$temp_file_name_1"."$target_image_prefix"."$temp_num"."$temp_file_name_2";
	return $y_file_name;
}

sub get_y_image_num_from_filename {
	my $digit_count =0;
	my $p_loc = index($_[0],"_",0);
	if ($p_loc == -1){
		$digit_count = 0;
	}
	else{
		if($global_entry_goods_variationflag == 1){
			$digit_count = substr($_[0], 6, get_image_numdigit_from_filename($_[0], 5));
		}
		else{
			$digit_count = substr($_[0], 10, get_image_numdigit_from_filename($_[0], 9));
		}
	}
	return $digit_count;
}

sub get_image_numdigit_from_filename {
	my $file_name=$_[0];
	my $goods_code_digit=$_[1]+1;
	# ファイル名からファイル番号を桁数を意識して取得
	my $digit_count=0;
	my $file_count=substr($file_name, $goods_code_digit, 2);
	if (index($file_count, '.') != -1) {
		$digit_count = 1;
	}
	else {
		$digit_count = 2;
	}
	return $digit_count;	
}
