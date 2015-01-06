package ImgResize;
#
# ImgResize.pm : 縮小画像を JPEG で出力するモジュール
#
#                      Copyright (C), 2004-2005 cachu <cachu@cachu.xrea.jp>
#
#     JPEG/PNG/GIF 画像を読み込んで縮小された JPEG 画像を出力します。
# 画像の縮小に利用できるプログラム及び Perl モジュールは以下の通りと
# なります。
#
#          ・ ImageMagick Perl モジュール (PerlMagick)
#          ・ GD          Perl モジュール
#          ・ gcon
#          ・ convert           (ImageMagick)
#          ・ repng2jpg
#          ・ netpbm            (jpegtopnm/pngtopnm/giftopnm/pnmtojpeg)
#
# gcon, repng2jpg は菅さん作のプログラムです。これらのプログラムは
#
#             http://sugachan.dip.jp/download/komono.php
#
# 入手可能です。2004/06/21 より GIF 形式に対応されたようですのですでに
# 入手をされていた方は最新版にして下さい。
#
#     使い方については
#
#             http://cachu.xrea.jp/perl/
#
# を参考にしてください。
#
#     このスクリプトの再配布、改変及びサブルーチンを抜き出して利用して
# いただいても構いません。ただし、著作権を放棄したわけではありませんので
# きちんとその旨はどこかに明記してください。
#
#
# method...
#   -1: 自動検出
#    0: サムネイル作成せず
#    1: PerlMagick
#    2: gcon
#    3: convert
#    4: repng2jpg
#    5: netpbm
#    6: GD Perl モジュール
#   99: user define

$convert    = '/usr/bin/convert';
$jpegtopnm  = '/usr/bin/jpegtopnm';
$pnmscale   = '/usr/bin/pnmscale';
$pngtopnm   = '/usr/bin/pngtopnm';
$giftopnm   = '/usr/bin/giftopnm';
$pnmtojpeg  = '/usr/bin/pnmtojpeg';
$pamflip    = '/usr/bin/pamflip';
$repng2jpeg = './repng2jpeg';
#$gif2png    = './gif2png';
$gcon       = './gcon.exe';
$init       = 0;
$rotate     = 0;

# モジュールの初期化
sub new{
    my ( $pkg, $method ) = @_;
    my $this = {};

    bless $this;
    ( !$method ) and ( $method = -1 );
    $this->{method} = &Init( $method );

    $this;
}

# リサイズ
sub resize{
    my ( $this ) = @_;

    ( $this->{rotate} ) and ( $rotate = $this->{rotate} );
    return unless ( $this->{width}    );
    return unless ( $this->{height}   );
    return unless ( $this->{quality}  );
    return unless ( $this->{ext}      );
    return unless ( $this->{in}       );
    return unless ( $this->{out}      );
    return unless ( $this->{exif_cut} );

    &Resize( $this->{method},
	     $this->{width},
	     $this->{height},
	     $this->{quality},
	     $this->{ext},
	     $this->{in},
	     $this->{out},
	     $this->{exif_cut},
	     $this->{jpeg_prog},
	     $this->{png_prog},
	     $this->{gif_prog}
	     );
	     
}

# リサイズプログラムの決定
sub Init{
    my ( $method, $skip ) = @_;
    my ( $i, $norder );
    my @result = ();
    my $result = 0;

    my @order = ( 1, 6, 2, 3, 4, 5 );

    $init   = 1;
    $norder = @order;

    if( $skip   == 1 ){ return $method; }
    if( $method == 0 || $method == 99 ){ return $method; }

    ( eval 'use Image::Magick; 1;' ) ? ( $result[1] = 1 ) : ( $result[1] = 0 );
    ( -x $gcon       ) ? ( $result[2] = 1 ) : ( $result[2] = 0 );
    ( -x $convert    ) ? ( $result[3] = 1 ) : ( $result[3] = 0 );
    ( -x $repng2jpeg ) ? ( $result[4] = 1 ) : ( $result[4] = 0 );
#    ( -x $gif2png    ) ? ( $result[4] = 1 ) : ( $result[4] = 0 );
    ( -x $jpegtopnm  ) ? ( $result[5] = 1 ) : ( $result[5] = 0 );
    ( -x $pnmscale   ) ? ( $result[5] = 1 ) : ( $result[5] = 0 );
    ( -x $pngtopnm   ) ? ( $result[5] = 1 ) : ( $result[5] = 0 );
    ( -x $giftopnm   ) ? ( $result[5] = 1 ) : ( $result[5] = 0 );
    ( eval 'use GD; 1;' ) ? ( $result[6] = 1 ) : ( $result[6] = 0 );

    for( $i = 0 ; $i <= $norder ; $i++ ){
	if( $method == -1 && $result[$order[$i]] == 1 ){
	    $result = $order[$i];
	    last;
	}elsif( $method == $order[$i] && $result[$order[$i]] == 1 ){
	    $result = $order[$i];
	    last;
	}
    }

    return $result;
}

# リサイズサブルーチン
sub Resize{
    my ( $method, $w, $h, $q, $ext, $in, $out,
	 $cut_exif, $jpeg_prog, $png_prog, $gif_prog ) = @_;
    my ( $i, $progs, @jpeg_prog, @png_prog, @gif_prog );
    my ( $hratio, $vratio );

    my $image_rotate = '';
    my $id = 0;

    my ( $format, $width, $height ) = &InquireImageSize( $in );

    # エラーチェック
    return if( $width < 0 );
    ( $init != 1 ) and ( $method = &Init( $method ) );
    return if ( $method == 6 && $ext eq '.gif' );

    ( $q < 0 || $q > 100 ) ? ( $q = 75 ) : ( $q = int( $q ) );
    ( $w < 0 || $h < 0   ) and ( return );

    $hratio = $w / $width;
    $vratio = $h / $height;

    # Image::Magick (PerlMagic)
    if( $method == 1 ){
	my $image = Image::Magick->new;
	$image->Read( $in );
	if( $rotate != 0. ){
	    $image_rotate = sprintf( "%f", $rotate );
	    $image->Rotate( degrees=>$image_rotate );
	}
	$image->Resize( geometry=>"${w}x${h}" );
	$image->Set( quality=>$q );
	$image->Write( $out );
	$id = 1;

    # gcon
    }elsif( $method == 2 ){
	system( "$gcon sj ${w}-${h} $in $out -q $q" );

    # convert (ImageMagick)
    }elsif( $method == 3 ){
	if( $rotate != 0. ){
	    $image_rotate = sprintf( "-rotate %f", $rotate );
	}
	system( "$convert -geometry ${w}x${h} $image_rotate -quality $q $in $out" );
	$id = 1;

    # repng2jpeg/gif2png
    }elsif( $method == 4 ){
	system( "$repng2jpeg $in $out $w $h $q" );
#	if( $ext ne '.gif' ){
#	    system( "$repng2jpeg $in $out $w $h $q" );
#	}else{
#	    my $png = $in;
#	    $png =~ s/\.gif$/\.png/;
#	    system( "$gif2png $in" );
#	    system( "$repng2jpeg $png $out $w $h $q" );
#	    unlink( $png );
#	}

    # netpbm
    }elsif( $method == 5 ){
	( $hratio > $vratio ) 
	    ? ( $w = $width * $vratio ) : ( $h = $height * $hratio );
	if( -x $pamfilp ){
	    if( $rotate == 90 ){
		$image_rotate = " | $pamflip -r270 ";
	    }elsif( $rotate == 180 ){
		$image_rotate = " | $pamflip -r180 ";
	    }elsif( $rotate == -90 || $rotate == 270 ){
		$image_rotate = " | $pamflip -r90 ";
	    }
	}

	if( $ext eq '.jpg' ){
	    system( "$jpegtopnm $in | $pnmscale -xsize $w -ysize $h $image_rotate | $pnmtojpeg --quality=$q > $out" );
	}elsif( $ext eq '.png' ){
	    system( "$pngtopnm $in | $pnmscale -xsize $w -ysize $h $image_rotate | $pnmtojpeg --quality=$q > $out" );
	}elsif( $ext eq '.gif' ){
	    system( "$giftopnm $in | $pnmscale -xsize $w -ysize $h $image_rotate | $pnmtojpeg --quality=$q > $out" );
	}

    # GD module
    }elsif( $method == 6 ){
	( $hratio > $vratio ) 
	    ? ( $w = $width * $vratio ) : ( $h = $height * $hratio );
	my ( $in_img, $out_img );

	if( $format =~ /JPEG/i ){
	    $in_img = GD::Image->newFromJpeg( $in );
	}elsif( $format =~ /PNG/i ){
	    $in_img = GD::Image->newFromPng( $in );
	}else{
	    return;
	}

	# for GD ver 2.x
	eval {
	    $out_img = GD::Image->newTrueColor( $w, $h );
	    $out_img->copyResampled( $in_img, 0, 0, 0, 0,
				     $w, $h,
				     $width, $height );
	    if( $rotate == 90 ){
		my $out_tmp = $out_img->copyRotate90();
		$out_img = $out_tmp;
	    }elsif( $rotate == 180 ){
		my $out_tmp = $out_img->copyRotate180();
		$out_img = $out_tmp;
	    }elsif( $rotate == -90 || $rotate == 270 ){
		my $out_tmp = $out_img->copyRotate270();
		$out_img = $out_tmp;
	    }
	};

	# for GD ver 1.x
	if( $@ ){
	    eval{
		$out_img = GD::Image->new( $w, $h );;
		$out_img->copyResized( $in_img, 0, 0, 0, 0,
				       $w, $h,
				       $width, $height );
	    };
	}

	open( ImgOut, ">$out" );
	print ImgOut $out_img->jpeg( $q );
	close( ImgOut );

    # user define
    }elsif( $method == 99 ){
	if( $ext eq '.jpg' ){
	    $jpeg_prog =~ s/\%w/$w/g;
	    $jpeg_prog =~ s/\%h/$h/g;
	    $jpeg_prog =~ s/\%q/$q/g;
	    $jpeg_prog =~ s/\%i/$in/g;
	    $jpeg_prog =~ s/\%o/$out/g;
	    @jpeg_prog = split( /\\n/, $jpeg_prog );
	    $progs = @jpeg_prog;
	    for( $i = 0 ; $i < $progs ; $i++ ){
		system( "$jpeg_prog[$i]" );
	    }
	    $id = 1;

	}elsif( $ext eq '.png' ){
	    $png_prog =~ s/\%w/$w/g;
	    $png_prog =~ s/\%h/$h/g;
	    $png_prog =~ s/\%q/$q/g;
	    $png_prog =~ s/\%i/$in/g;
	    $png_prog =~ s/\%o/$out/g;
	    @png_prog = split( /\\n/, $png_prog );
	    $progs = @png_prog;
	    for( $i = 0 ; $i < $progs ; $i++ ){
		system( "$png_prog[$i]" );
	    }

	}elsif( $ext eq '.gif' ){
	    $gif_prog =~ s/\%w/$w/g;
	    $gif_prog =~ s/\%h/$h/g;
	    $gif_prog =~ s/\%q/$q/g;
	    $gif_prog =~ s/\%i/$in/g;
	    $gif_prog =~ s/\%o/$out/g;
	    @gif_prog = split( /\\n/, $gif_prog );
	    $progs = @gif_prog;
	    for( $i = 0 ; $i < $progs ; $i++ ){
		system( "$gif_prog[$i]" );
	    }
	}
    }

    # アニメーション GIF 対策
    if( $ext eq '.gif' ){
        unless( -e $out ){
            if( -e "$out\.0" ){
                rename( "$out\.0", $out );
            }
        }
        unlink( <$out\.*> );
    }

    ( $id == 1 && $cut_exif == 1 ) and ( &JPEGCommentCut( $out ) );
}

sub JPEGCommentCut{
    my ( $out ) = @_;
    my ( $tmp, $mark, $buf, $type1, $type2, $fpos, $f_size );
    my $id = 0;

    $tmp  = $out . '_tmp';
    $mark = pack( "C", 0xFF );

    open( IN, $out );
    open( OUT, ">$tmp" );
    binmode( IN  );
    binmode( OUT );

    read( IN, $buf, 2 );
    print OUT $buf;
    ( $type1, $type2 ) = unpack( "C*", $buf );
    $fpos = 2;

    if( $type1 == 0xFF && $type2 == 0xD8 ){
      JPEG: while( read( IN, $type1, 1 ) ){
	  $fpos++;
	  if( ( $type1 eq $mark ) && read( IN, $buf, 3 ) ){
	      $fpos  += 3;
	      $type2  = unpack( "C*", substr( $buf, 0, 1 ) );
	      $f_size = unpack( "n*", substr( $buf, 1, 2 ) );

	      # カットするマーカー。現在は APP1, APP2
	      if( $type2 == 0xE1 ||
		  $type2 == 0xE2 ){
		  seek( IN, $f_size-2, 1);
		  $id = 1;

	      # FFDA が来たら後は全部書出す
	      }elsif( $type2 == 0xDA ){
		  print OUT $type1;
		  print OUT $buf;
		  print OUT $buf while( read( IN, $buf, 16384 ) );

	      # 単独のマーカー
	      }elsif( $type2 == 0xD0 || $type2 == 0xD1 ||
		      $type2 == 0xD2 || $type2 == 0xD3 ||
		      $type2 == 0xD4 || $type2 == 0xD5 ||
		      $type2 == 0xD6 || $type2 == 0xD7 ||
		      $type2 == 0x01 ){
		  print OUT $type1;
		  print OUT $buf;
	      }else{
		  print OUT $type1;
		  print OUT $buf;
		  read( IN, $buf, $f_size-2 );
		  print OUT $buf;
	      }


	  }else{
	      print OUT $type1;
	  }
      }
    }
    close( IN );
    close( OUT );
    if( $id == 1 ){ rename( $tmp, $out ); }
    unlink( $tmp );
}

# JPEG/PNG/GIF の画像の幅と高さを取得する
sub InquireImageSize{
    my ( $IMG ) = @_;
    my ( $buf, $format, $width, $height, $offset, $CODE );
    my ( $mark, $type, $type2, $f_size );

    $format = '';
    $width  = -1;
    $height = -1;

    open( ImgResize, $IMG ) || return( '', -1 , -1 );
    binmode( ImgResize );
    seek( ImgResize,    0, 0 );
    read( ImgResize, $buf, 6 );

    # GIF format;
    if( $buf =~ /^GIF/i ){
	$format = 'GIF';
	read( ImgResize, $buf, 2 );
	$width = unpack( "v*", $buf );
	read( ImgResize, $buf, 2 );
	$height = unpack( "v*", $buf );
	
    }elsif( $buf =~ /PNG/ ){
	$format = 'PNG';
	seek( ImgResize, 8, 0 );

	while( 1 ){
	    read( ImgResize, $buf, 8 );
	    ( $offset, $CODE ) = unpack( "NA4", $buf );

	    if( $CODE eq 'IHDR' ){
		read( ImgResize, $buf, 8 );
		( $width, $height ) = unpack( "NN", $buf );
		seek( ImgResize, $offset-8+4, 1 );
		last;
	    }elsif( $CODE eq 'IEND' ){
		last;
	    }else{
		seek( ImgResize, $offset+4, 1 );
	    }
	}

    }else{
	# JPEG format
	$mark = pack( "C", 0xff );
	seek( ImgResize, 0, 0 );
	read( ImgResize, $buf, 2 );
	( $buf, $type ) = unpack( "C*", $buf );

        if( $buf == 0xFF && $type == 0xD8 ){
            $format = 'JPEG';

          JPEG:while( read( ImgResize, $buf, 1 ) ){
              if( ( $buf eq $mark ) && read( ImgResize, $buf, 3 ) ){
                  $type   = unpack( "C*", substr($buf, 0, 1) );
                  $f_size = unpack( "n*", substr($buf, 1, 2) );

                  ( $type == 0xD9 ) and ( last JPEG );
                  ( $type == 0xDA ) and ( last JPEG );

                  if($type == 0xC0 || $type == 0xC2){
                      read( ImgResize, $buf, $f_size-2 );
                      $height = unpack( "n*", substr( $buf, 1, 2 ) );
                      $width  = unpack( "n*", substr( $buf, 3, 2 ) );
		      last JPEG;

                  }elsif( $type2 == 0x01 || 
                          ( $type2 >= 0xD0 && $type2 < 0xD9 ) ){
                      seek( ImgResize, -2, 1 );

                  }else{
                      read( ImgResize, $buf, $f_size-2 );
                  }
              }
          }
        }
	
	
    }

    close( ImgResize );
    return ( $format, $width, $height );
}

1;

=head1 NAME

ImgResize.pm - Resize from JPEG/PNG/GIF image to JPEG image.

=head1 SYNOPSIS

    use ImgResize;

    # create a new image
    $image = new ImgResize( -1 );

    # set variables
    $image->{width}    = 300;        # width of the output image
    $image->{height}   = 300;        # height of the output image
    $image->{quality}  =  75;        # JPEG quality
    $image->{ext}      = '.jpg';     # an extension for the input image
    $image->{in}       = 'in.jpg';   # input file name
    $image->{out}      = 'out.jpg';  # output file name

    # make the resized image
    $image->resize;

=head1 DESCRIPTION

B<ImgResize.pm> is ...

=head2 Variables

ImgResize has some variables. Variables which the user can define are
as follows;

=item B<ImgResize::convert>

The path of the C<convert> command. Default is C</usr/bin/convert>.

=item B<ImgResize::jpegtopnm>

The path of the C<jpegtopnm> command. Default is C</usr/bin/jpegtopnm>.

=item B<ImgResize::pnmscale>

The path of the C<pnmscale> command. Default is C</usr/bin/pnmscale>.

=item B<ImgResize::pngtopnm>

The path of the C<pngtopnm> command. Default is C</usr/bin/pngtopnm>.

=item B<ImgResize::giftopnm>

The path of the C<giftopnm> command. Default is C</usr/bin/giftopnm>.

=item B<ImgResize::pnmtojpeg>

The path of the C<pnmtojpeg> command. Default is C</usr/bin/pnmtojpeg>.

=item B<ImgResize::pamflip>

The path of the C<pamflip> command. Default is C</usr/bin/pamflip>.

=item B<ImgResize::repng2jpeg>

The path of the C<repng2jpeg> command. Default is C<./repng2jpeg>.

=item B<ImgResize::gcon>

The path of the C<gcon> command. Default is C<./gcon.exe>.

=item B<ImgResize::rotate>



=head1 AUTHOR

The ImgResize.pm is copyright 2004-2005, cachu <cachu@cachu.xrea.jp>.
The latest version  of ImgResize.pm is available at

          http://cachu.xrea.jp/perl/ImgResize.html

=cut

    
