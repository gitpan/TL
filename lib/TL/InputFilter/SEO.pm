# -----------------------------------------------------------------------------
# TL::InputFilter::SEO - SEO入力フィルタ
# -----------------------------------------------------------------------------
package TL::InputFilter::SEO;
use strict;
use warnings;
use TL;
require TL::InputFilter;
our @ISA = qw(TL::InputFilter);

# このフィルタは次のようなPATH_INFOからフォーム情報を得る。
# foo.cgi/aaa/100/bbb/200
# => aaa=100&bbb=200

# このフィルタをSession及びTL::Filter::MobileHTMLと併用する場合は
# TL::Filter::MobileHTMLよりも先に呼ばれるように設定しなければならない。

1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	$this;
}

sub decodeCgi {
	my $this = shift;
	my $form = shift;

	my $newform = $this->_formFromPairs(
	$this->__pairsFromPathInfo);

	$form->addForm($newform);

	$this;
}

sub decodeURL {
	my $this = shift;
	my $form = shift;
	my $url = shift; # フラグメントは除去済
	my $fragment = shift;

	# URLの何処からPATH_INFOが始まっているのか
	# 判断する方法は無い。

	$this;
}

sub __pairsFromPathInfo {
	# 戻り値: ([[key => value], ...], {key => filename, ...})
	#         但しkey, value共にURLデコードされている事。文字コードは生のまま。
	my $this = shift;

	if(!defined($ENV{PATH_INFO})) {
		return ([], undef);
	}

	my @split = map { $this->_urlDecodeString($_) } split m!/!, $ENV{PATH_INFO};
	shift @split; # 最初の項目は常に空。PATH_INFOがスラッシュで始まる為。

	my @pairs;
	while(@split) {
		if(defined($split[0]) && $split[0] eq 'SEO') {
			shift(@split);
			shift(@split);
			next;
		}
		my $key = shift(@split);
		my $value = shift(@split);
		if(!defined($value)) {
			$value = '';
		}
		push @pairs, [$key => $value];
	}
	return (\@pairs, {});
}


__END__

=encoding utf-8

=head1 NAME

TL::InputFilter::SEO - input filter for SEO (ja)

=head1 NAME (ja)

TL::InputFilter::SEO::JA - SEO入力フィルタ

=head1 SYNOPSIS

  $TL->setInputFilter(['TL::InputFilter::SEO', 999]);
  $TL->setInputFilter('TL::InputFilter::HTML');
  
  $TL->startCgi(
      -main => \&main,
  );
  
  sub main {
      if ($CGI->get('mode') eq 'Foo') {
          ...
      }
  }

=head1 DESCRIPTION

このフィルタは次のような C<PATH_INFO> からフォーム情報を得る。

  foo.cgi/aaa/100/bbb/200
  => aaa=100&bbb=200


注意:
  
このフィルタを L<TL::Session> 及び L<TL::InputFilter::MobileHTML>
と併用する場合は、 それらよりも先に呼ばれるように設定しなければならない。

=head2 METHODS

=over 4

=item decodeCgi

内部メソッド

=item decodeURL

内部メソッド

=back

=head1 SEE ALSO

=over 4

=item L<TL>

=item L<TL::InputFilter>

=item L<TL::InputFilter::MobileHTML>

=item L<TL::Session>

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
