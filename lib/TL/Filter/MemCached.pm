# -----------------------------------------------------------------------------
# TL::Filter::MemCached - MemCachedを使用するときに使用するフィルタ
# -----------------------------------------------------------------------------
package TL::Filter::MemCached;
use strict;
use warnings;
use TL;
require TL::Filter;
our @ISA = qw(TL::Filter);

# このフィルタは必ず最後に呼び出されなければならない。
# オプション一覧:
# * key     => MemCachedから読み込む際のキー
# * type     => MemCachedへの書き込み(in)か、MemCachedからの出力(out)か。
# * param    => 書き込み時に埋め込むデータ。TL::Fromクラスの形で渡す。
# * charset     => 書き込み時に埋め込むデータを変換するための、出力の文字コード。(UTF-8から変換される)
#                  Encode.pmが利用可能なら利用する。(UniJP一部互換エンコード名、sjis絵文字使用不可)
#                  デフォルト: Shift_JIS


1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	# デフォルト値を埋める。
	my $defaults = [
		[charset => 'Shift_JIS'],
		[key     => undef],
		[type    => 'in'],
		[param   => undef],
	];
	$this->_fill_option_defaults($defaults);

	# オプションのチェック
	my $check = {
		charset     => [qw(defined no_empty scalar)],
		key     => [qw(defined no_empty scalar)],
		type     => [qw(defined no_empty scalar)],
		param     => [qw(no_empty)],
	};
	$this->_check_options($check);

	if($this->{option}{type} ne 'in' && $this->{option}{type} ne 'out') {
		die "TL#setContentFilter, option [type] for [TL::Filter::MemCache] ".
			"must be 'in' or 'out' instead of [$this->{option}{type}].\n";
	}

	$this->{buffer} = '';

	$this;
}

sub print {
	my $this = shift;
	my $data = shift;

	if(ref($data)) {
		die __PACKAGE__."#print, ARG[1] was a Ref. [$data]\n";
	}
	
	return '' if($data eq '');
	
	if($this->{option}{type} eq 'in') {
		$this->{buffer} .= $data;
	} else {
		if($this->{buffer} eq '') {
			$this->{buffer} = $data;
		} else {
			die __PACKAGE__."#print, already output.\n";
		}
	}
	
	'';
}

sub flush {
	my $this = shift;

	my $output;
	if($this->{option}{type} eq 'in') {
		my $nowtime = time;
		$output = q{Last-Modified: } . $TL->newDateTime->setEpoch($nowtime)->toStr('rfc822') . qq{\r\n} . $this->{buffer};
		my $value = $nowtime . q{,} . $output;
		$TL->newMemCached->set($this->{option}{key},$value);
		if(defined($this->{option}{param})) {
			foreach my $key2 ($this->{option}{param}->getKeys){
				my $val = $TL->charconv($this->{option}{param}->get($key2), 'UTF-8' => $this->{option}{charset});
				$output =~ s/$key2/$val/g;
			}
		}
	} else {
		$output = $this->{buffer};
	}

	$this->_reset;
	
	$output;
}

sub _reset {
	my $this = shift;
	$this->SUPER::_reset;
	
	$this->{buffer} = '';
	
	$this;
}



__END__

=encoding utf-8

=head1 NAME

TL::Filter::MemCached - MemCachedを使用するときに使用するフィルタ

=head1 SYNOPSIS

  $TL->setContentFilter('TL::Filter::MemCached',key => 'key', type => 'out', param => $param,  charset => 'Shift_JIS');

=head1 DESCRIPTION

MemCachedの使用を支援する。
このフィルタを使用する場合、最後に使用しなければならない。

=head2 METHODS

=over 4

=item flush

L<TL::Filter>参照

=item print

L<TL::Filter>参照

=back

=head2 フィルタパラメータ

=over 4

=item key

MemCachedで使用するkeyを設定する。

=item type

MemCachedへの書き込みか、MemCachedからの出力かを選択する。

inで書き込み、outで出力。省略可能。

デフォルトはin。

=item param

inで書き込みをする際に、出力文字列中に最後に埋め込みを行う情報をL<TL::Form> クラスのインスタンスで指定する。
L<TL::Form>クラスのキーが出力文字列中に存在している場合、値に置換する。省略可能。

=item charset

paramの値をUTF-8から変換する際の文字コードを指定する。省略可能。

使用可能なコードは次の通り。
UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP

デフォルトはShift_JIS。

=back

=head1 SEE ALSO

=over 4

=item L<TL>

=item L<TL::Filter>

=item L<TL::MemCached>

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
