#!/usr/bin/perl

use strict;
use warnings;

use TL q(customfilter.ini);

$TL->startCgi(
	      -main => \&main,
	     );


sub main {

  # カスタムフィルタを設定します．
  # 通常のHTMLフィルタの前に処理を挟むことにします．
  #
  # HTMLフィルタは，ヘッダ補完・文字コード変換を行いますので，
  # HTMLフィルタの前に挟んだ場合は，入出力はUTF-8になります．
  # HTMLフィルタの後に挟んだ場合は，指定により
  # 文字コードが様々になる上，ヘッダも渡されるため，
  # 今回の目的には適しません．
  #
  # 通常のHTMLフィルタは優先度 1000 となっているので，
  # 優先度 900 で登録します．

  $TL->setContentFilter(['CustomFilter', 900]);

  my $t = $TL->newTemplate('customfilter.html');
  $t->flush;

}



