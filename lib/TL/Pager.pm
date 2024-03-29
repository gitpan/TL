# -----------------------------------------------------------------------------
# TL::Pager - ページング処理
# -----------------------------------------------------------------------------
package TL::Pager;
use strict;
use warnings;
use TL;

1;

sub _new {
	my $class = shift;
	my $this = bless {} => $class;

	$this->{dbgroup} = undef;
	$this->{pagesize} = 30;
	$this->{current} = 1;
	$this->{maxlinks} = 10;
	$this->{formkey} = 'pageid';
	$this->{formparam} = undef;
	$this->{pagingtype} = 0;

#結果群
	$this->{maxpages} = undef;
	$this->{linkstart} = undef;
	$this->{linkend} = undef;
	$this->{maxrows} = undef;
	$this->{beginrow} = undef;
	$this->{rows} = undef;
	
	if(@_) {
		$this->setDbGroup(@_);
	}

	$this->setFormParam(undef);
	$this;
}

sub setDbGroup {
	my $this = shift;
	my $dbgroup = shift;

	if(ref($dbgroup)) {
		die __PACKAGE__."#setDbGroup, ARG[1] was a Ref. [$dbgroup]\n";
	}

	$this->{dbgroup} = $dbgroup;
	$this;
}

sub setPageSize {
	my $this = shift;
	my $size = shift;

	if(!defined($size)) {
		die __PACKAGE__."#setPageSize, ARG[1] was undef.\n";
	} elsif(ref($size)) {
		die __PACKAGE__."#setPageSize, ARG[1] was a Ref. [$size]\n";
	} elsif($size !~ /^\d+$/ || $size <= 0) {
		die __PACKAGE__."#setPageSize, ARG[1] was not a positive number. [$size]\n";
	}

	$this->{pagesize} = $size;
	$this;
}

sub setCurrentPage {
	my $this = shift;
	my $page = shift;

	if(!defined($page)) {
		die __PACKAGE__."#setCurrentPage, ARG[1] was undef.\n";
	} elsif(ref($page)){
		die __PACKAGE__."#setCurrentPage, ARG[1] was a Ref. [$page]\n";
	} elsif($page !~ /^\d+$/ || $page <= 0) {
		die __PACKAGE__."#setCurrentPage, ARG[1] was not a positive number. [$page]\n";
	}

	$this->{current} = $page;
	$this;
}

sub setMaxLinks {
	my $this = shift;
	my $maxlinks = shift;

	if(!defined($maxlinks)) {
		die __PACKAGE__."#setMaxLinks, ARG[1] was undef.\n";
	} elsif(ref($maxlinks)){
		die __PACKAGE__."#setMaxLinks, ARG[1] was a Ref. [$maxlinks]\n";
	} elsif($maxlinks !~ /^\d+$/ || $maxlinks <= 0) {
		die __PACKAGE__."#setMaxLinks, ARG[1] was not a positive number. [$maxlinks]\n";
	}

	$this->{maxlinks} = $maxlinks;
	$this;
}

sub setFormKey {
	my $this = shift;
	my $key = shift;

	if(!defined($key)) {
		die __PACKAGE__."#setFormKey, ARG[1] was undef.\n";
	} elsif(ref($key)) {
		die __PACKAGE__."#setFormKey, ARG[1] was a Ref. [$key]\n";
	}

	$this->{formkey} = $key;
	$this;
}

sub setFormParam {
	my $this = shift;
	my $form = shift;

	if(!defined($form)) {
		$this->{formparam} = $TL->newForm;
	} else {
		if(ref($form) ne 'TL::Form') {
			die __PACKAGE__."#setFormParam, ARG[1] was not an instance of TL::Form. [$form]\n";
		} else {
			$this->{formparam} = $form->clone;
		}
	}

	$this;
}

sub setPagingType {
	my $this = shift;
	my $type = shift;

	if(!defined($type)) {
		die __PACKAGE__."#setPagingType, ARG[1] was undef.\n";
	} elsif(ref($type)) {
		die __PACKAGE__."#setPagingType, ARG[1] was a Ref. [$type]\n";
	} elsif($type !~ /^[01]$/) {
		die __PACKAGE__."#setPagingType, ARG[1] was not 0 or 1. [$type]\n";
	}

	$this->{pagingtype} = $type;
	$this;
}

sub getPagingInfo {
	my $this = shift;

	$this;
}

sub paging {
	my $this = shift;
	$this->_paging(0, @_);
}

sub pagingArray {
	my $this = shift;
	$this->_paging(1, @_);
}

sub pagingHash {
	my $this = shift;
	$this->_paging(2, @_);
}

sub _paging {
	my $this = shift;
	my $resulttype = shift; # 0:件数(Row展開有), 1:配列(Row展開無), 2:ハッシュ(Row展開無)
	my $node = shift;
	my $query = shift;
	my @params = @_;
	my $result;

	my $DB = $TL->getDB($this->{dbgroup});

	if(ref($query) eq 'ARRAY') {
		($query, $this->{maxrows}) = @$query;
	}

	if(!defined($node)) {
		die __PACKAGE__."#paging, ARG[2] was undef.\n";
	} elsif(ref($node) ne 'TL::Template::Node') {
		die __PACKAGE__."#paging, ARG[2] was a Ref. [$node]\n";
	}
	
	if(!defined($query)) {
		die __PACKAGE__."#paging, ARG[3] was undef.\n";
	} elsif(ref($query)) {
		die __PACKAGE__."#paging, ARG[3] was a Ref. [$query]\n";
	}

	my $query_back = $query;

	if(defined($this->{maxrows})) {
		if(ref($this->{maxrows})) {
			die __PACKAGE__."#paging, ARG[3] was a Ref. [$this->{maxrows}]\n";
		} elsif($this->{maxrows} !~ /^\d+$/ || $this->{maxrows} < 0) {
			die __PACKAGE__."#paging, ARG[3] was not a positive number. [$this->{maxrows}]\n";
		}
	} else {
	# SQL_CALC_FOUND_ROWSを勝手に付ける。
		$query =~ s/SELECT/SELECT SQL_CALC_FOUND_ROWS/i;
	}

	# 何行目から表示すれば良いのか計算。
	$this->{beginrow} = ($this->{current} - 1) * $this->{pagesize};

	# LIMITを勝手に付ける。
	$query .= sprintf "\nLIMIT %d, %d", $this->{beginrow}, $this->{pagesize};

	# SQL実行
	if($resulttype == 0) {
		my $sth = $DB->execute($query, @params);
		while(my $row = $sth->fetchHash) {
			$node->node('Row')->add($row);
		}
		$this->{rows} = $sth->rows + 0;
		$result = $this->{rows};
	} elsif($resulttype == 1) {
		$result = $DB->selectAllArray($query, @params);
		$this->{rows} = scalar(@$result);
	} elsif($resulttype == 2) {
		$result = $DB->selectAllHash($query, @params);
		$this->{rows} = scalar(@$result);
	}

	# 全部で何件あるか調べる
	unless(defined($this->{maxrows})) {
		my $sth = $DB->execute(q{SELECT FOUND_ROWS() as ROWS});
		my $count = $sth->fetchArray;
		$sth->finish;

		$this->{maxrows} = $count->[0];
	}

	if($this->{maxrows} == 0) {
		# 検索結果が無かった
		return 0;
	}

	# 総頁数
	$this->{maxpages} = int(($this->{maxrows} - 1) / $this->{pagesize}) + 1;
	if($this->{current} > $this->{maxpages}) {
		# 存在する頁数を越えて現在頁が設定されている。
		if($this->{pagingtype} == 1){
			# typeが1なので最大ページを現在のページに設定して再検索。
			$this->{current} = $this->{maxpages};

			# 何行目から表示すれば良いのか計算。
			$this->{beginrow} = ($this->{current} - 1) * $this->{pagesize};
			# LIMITを勝手に付ける。
			$query_back .= sprintf "\nLIMIT %d, %d", $this->{beginrow}, $this->{pagesize};

			if($resulttype == 0) {
				my $sth = $DB->execute($query_back, @params);
				while(my $row = $sth->fetchHash) {
					$node->node('Row')->add($row);
				}
				$this->{rows} = $sth->rows + 0;
				$result = $this->{rows};
			} elsif($resulttype == 1) {
				$result = $DB->selectAllArray($query_back, @params);
				$this->{rows} = scalar(@$result);
			} elsif($resulttype == 2) {
				$result = $DB->selectAllHash($query_back, @params);
				$this->{rows} = scalar(@$result);
			}
		} else {
			# typeが0なのでここで終了。
			# ページリンク
			$this->{linkstart} = $this->{maxpages} - int($this->{maxlinks} / 2);
			if($this->{linkstart} < 1) {
				$this->{linkstart} = 1;
			}

			$this->{linkend} = $this->{linkstart} + $this->{maxlinks} - 1;
			if($this->{linkend} > $this->{maxpages}) {
				$this->{linkend} = $this->{maxpages};

				# linkendを変えたので、startの方を再度変更
				$this->{linkstart} = $this->{linkend} - $this->{maxlinks} + 1;
				if($this->{linkstart} < 1) {
					$this->{linkstart} = 1;
				}
			}

			return undef;
		}
	}

	# リンクその他を展開
	if($this->{current} == 1) {
		$node->node('NoPrevLink')->add;
	} else {
		$node->node('PrevLink')->add(
			PREVLINK => $this->{formparam}->set(
					$this->{formkey} => $this->{current} - 1
				)->toLink,
		);
	}

	if($this->{current} == $this->{maxpages}) {
		$node->node('NoNextLink')->add;
	} else {
		$node->node('NextLink')->add(
			NEXTLINK => $this->{formparam}->set(
					$this->{formkey} => $this->{current} + 1
				)->toLink,
		);
	}

	# ページリンク
	$this->{linkstart} = $this->{current} - int($this->{maxlinks} / 2);
	if($this->{linkstart} < 1) {
		$this->{linkstart} = 1;
	}

	$this->{linkend} = $this->{linkstart} + $this->{maxlinks} - 1;
	if($this->{linkend} > $this->{maxpages}) {
		$this->{linkend} = $this->{maxpages};

		# linkendを変えたので、startの方を再度変更
		$this->{linkstart} = $this->{linkend} - $this->{maxlinks} + 1;
		if($this->{linkstart} < 1) {
			$this->{linkstart} = 1;
		}
	}

	foreach my $i ($this->{linkstart} .. $this->{linkend}) {
		if($i == $this->{current}) {
			$node->node('PageNumLinks')->node('ThisPage')->add(
				PAGENUM => $i,
			);
		} else {
			$node->node('PageNumLinks')->node('OtherPage')->add(
				PAGELINK => $this->{formparam}->set(
						$this->{formkey} => $i,
					)->toLink,
				PAGENUM  => $i,
			);
		}
		$node->node('PageNumLinks')->add;
	}

	# 必須でないノード
	if($node->exists('MaxRows')) {
		$node->node('MaxRows')->add(MAXROWS => $this->{maxrows});
	}

	if($node->exists('FirstRow')) {
		$node->node('FirstRow')->add(FIRSTROW => $this->{beginrow} + 1);
	}

	if($node->exists('LastRow')) {
		$node->node('LastRow')->add(LASTROW => $this->{beginrow} + $this->{rows});
	}

	if($node->exists('MaxPages')) {
		$node->node('MaxPages')->add(MAXPAGES => $this->{maxpages});
	}

	if($node->exists('CurPage')) {
		$node->node('CurPage')->add(CURPAGE => $this->{current});
	}

	$result;
}


__END__

=encoding utf-8

=head1 NAME

TL::Pager - ページング処理

=head1 SYNOPSIS

  my $pager = $TL->newPager('DB');
  $pager->setCurrentPage($CGI->get('pageid'));

  my $t = $TL->newTemplate('template.html');
  if($pager->paging($t->node('paging'), 'SELECT * FROM foo WHERE a = ?', 999)) {
    $t->node('paging')->add;
  } else {
    $t->node('nodata')->add;
  }

=head1 DESCRIPTION

ページング処理を行う。

決められた形式のTL::Templateノードに展開する。

=head2 テンプレート形式

  <!begin:paging>
    <!begin:PrevLink><a href="<&PREVLINK>">←前ページ</a><!end:PrevLink>
    <!begin:NoPrevLink>←前ページ<!end:NoPrevLink>
    <!begin:PageNumLinks>
      <!begin:ThisPage><&PAGENUM><!end:ThisPage>
      <!begin:OtherPage>
        <a href="<&PAGELINK>"><&PAGENUM></a>
      <!end:OtherPage>
    <!end:PageNumLinks>
    <!begin:NextLink><a href="<&NEXTLINK>">次ページ→</a><!end:NextLink>
    <!begin:NoNextLink>次ページ→<!end:NoNextLink>
    ...
    <!begin:MaxRows>全<&MAXROWS>件<!end:MaxRows>
    <!begin:FirstRow><&FIRSTROW>件目から<!end:FirstRow>
    <!begin:LastRow><&LASTROW>件目までを表示中<!end:LastRow>
    <!begin:MaxPages>全<&MAXPAGES>ページ<!end:MaxPages>
    <!begin:CurPage>現在<&CURPAGE>ページ目<!end:CurPage>
    ...
    <!begin:Row>
      <!-- 行データを展開する <&XXX> タグを記述する -->
    <!end:Row>
    ...
  <!end:paging>
  <!-- 以下は Pager クラスの処理とは関係ないため、無くても良い -->
  <!begin:nodata>
    一件もありません
  <!end:nodata>

必須でないノードは次の通り:
  
  MaxRows, FirstRow, LastRow, MaxPages,CurPage

これらのノードが存在しない場合は、単に無視される。

=head2 METHODS

=over 4

=item $TL->newPager

  $pager = $TL->newPager
  $pager = $TL->newPager($db_group)

Pagerオブジェクトを作成。
2番目の形式では、 L<デフォルト|TL::DB/"setDefaultSet"> の
L<DBセット|TL::DB/"DBセット"> が使われる。デフォルトが設定されていなければ
paging開始の時点でエラーとなる。

=item setDbGroup

  $pager->setDbGroup($db_group)
 
使用するDBのグループ名を指定する。

=item setPageSize

  $pager->setPageSize($line)

1ページに表示する行数を指定する。デフォルトは30。

=item setCurrentPage

  $pager->setCurrentPage($nowpage)

現在のページ番号を指定する。デフォルトは1。

=item setMaxLinks

  $pager->setMaxLinks($maxlinks)

各ページへのリンクを最大幾つ表示するかを指定する。デフォルトは10。

=item setFormKey

  $pager->setFormKey('PAGE')

ページ移動リンクに挿入される、ページ番号キーを指定する。デフォルトは"pageid"。

=item setFormParam

  $pager->setFormParam($CGI)

ページ移動リンクに追加されるフォームを指定する。デフォルトでは何も追加されない。

=item setPagingType

  $pager->setPagingType($type)

ページングの種類を選ぶ。

0の場合、最終ページを超えたページを指定した場合、undefが返る。
1の場合、最終ページを超えたページを指定した場合、最終ページが返る。

設定しなかった場合は0が設定される。

但し、1を選択した場合で、最終ページを超えるページを指定した場合、SQLを再度発行するため、通常より遅くなる。

=item getPagingInfo

  my $info = $pager->getPagingInfo

各種パラメータを返す。パラメータの内容は以下の通り。セットされてない場合はundefがセットされている。

=over 4

=item $info->{dbgroup}

使用するグループ名

=item $info->{pagesize}

1ページに表示する行数

=item $info->{current}

表示する（された）ページ番号

=item $info->{maxlinks}

リンクの最大数

=item $info->{formkey}

ページ移動リンクに挿入される、ページ番号キー

=item $info->{formparam}

ページ移動リンクに追加されるフォーム。TL::Formクラス

=item $info->{pagingtype}

ページングの種類

=item $info->{maxpages}

存在している最大ページ

=item $info->{linkstart}

リンクの開始ページ数

=item $info->{linkend}

リンクの終了ページ数

=item $info->{maxrows}

全体の件数

=item $info->{beginrow}

取得を開始した箇所

=item $info->{rows}

取得した件数

=back

=item paging

  $pager->paging($t->node('pagingblock'), $sql, @param)
  $pager->paging($t->node('pagingblock'), [$sql, $maxrows], @param)

指定したノードに、指定したSQLを実行してページングする。
展開するデータが1件も無い場合は 0 を、表示できるページ数を超えたページ数を指定
された場合は、setPagingTypeで設定されている値が0（デフォルト）であれば、undefが、
1であれば最終ページのデータ件数、それ以外の場合はデータ件数を返す。

$maxrows で件数のカウントを別途指定できる。
指定を省略した場合、SQL 文の先頭部分を SELECT COUNT(*) FROM ～ に書き換えたもの
を使用して、自動的に件数をカウントする。
その際、GROUP BY を使用した場合は、結果ではなく結果の件数をカウントとして扱う。
UNION を使用した場合は正常に動作しない。

=item pagingArray

  $result = $pager->pagingArray($t->node('pagingblock'), $sql, @param)
  $result = $pager->pagingArray($t->node('pagingblock'), [$sql, $maxrows], @param)

指定したノードに、指定したSQLを実行してページングする。
Row ノードは展開せずに、ページング対象のデータを配列の配列へのリファレンスで返す。
展開するデータが1件も無い場合は 0 を、表示できるページ数を超えたページ数を指定
された場合は、setPagingTypeで設定されている値が0（デフォルト）であれば、undefが、
1であれば最終ページのデータを返す。

その他は L</paging> と同じ。

=item pagingHash

  $result = $pager->pagingHash($t->node('pagingblock'), $sql, @param)
  $result = $pager->pagingHash($t->node('pagingblock'), [$sql, $maxrows], @param)

指定したノードに、指定したSQLを実行してページングする。
Row ノードは展開せずに、ページング対象のデータをハッシュの配列へのリファレンスで返す。
展開するデータが1件も無い場合は 0 を、表示できるページ数を超えたページ数を指定
された場合は、setPagingTypeで設定されている値が0（デフォルト）であれば、undefが、
1であれば最終ページのデータを返す。

その他は L</paging> と同じ。

=back


=head1 SEE ALSO

=over 4

=item L<TL>

=item L<TL::DB>

=back

=head1 AUTHOR INFORMATION

=over 4

Copyright 2006 YMIRLINK Inc. All Rights Reserved.

This framework is free software; you can redistribute it and/or modify it under the same terms as Perl itself

このフレームワークはフリーソフトウェアです。あなたは Perl と同じライセンスの 元で再配布及び変更を行うことが出来ます。

Address bug reports and comments to: tl@tripletail.jp

HP : http://tripletail.jp/

=back

=cut
