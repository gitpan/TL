#!/usr/bin/perl

use strict;
use warnings;

use TL q(csvdownload.ini);

$TL->startCgi(
	      -main => \&main,
	     );


sub main {

  # i = 1 ～ 100 で，i, i^2, i^3 の値を並べた
  # CSVファイルをダウンロードさせます．
  
  # 出力フィルタを CSV ダウンロード用に切り替えます．
  $TL->setContentFilter('TL::Filter::CSV',
			charset => 'Shift_JIS',
			filename => 'テストデータ.csv');

  # $TL->print で配列へのリファレンスを渡すと，CSVになって出力されます．
  $TL->print(['i', 'i^2', 'i^3']);
  for(my $i = 1; $i <= 100; $i++) {
    $TL->print([$i, $i**2, $i**3]);
  }

}



