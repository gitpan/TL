# -----------------------------------------------------------------------------
# TL::Filter::HeaderOnly - ヘッダのみ出力
# -----------------------------------------------------------------------------
package TL::Filter::HeaderOnly;
use strict;
use warnings;
use TL;
require TL::Filter;
our @ISA = qw(TL::Filter);

# オプション一覧:

1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	$this;
}

sub print {
	my $this = shift;
	
	'';
}
  
sub flush {
	my $this = shift;

	my $data = $this->_flush_header;

	$this->_reset;

	$data;
}

sub _reset {
	my $this = shift;
	$this->SUPER::_reset;

	$this;
}

__END__

=encoding utf-8

=head1 NAME

TL::Filter::HeaderOnly - Only the header is output. (ja)

=head1 NAME (ja)

TL::Filter::HeaderOnly::JA - ヘッダのみ出力

=head1 SYNOPSIS

  $TL->setContentFilter('TL::Filter::HeaderOnly');

=head1 DESCRIPTION

以下の処理を行う。

=over 4

=item ヘッダーのみを出力し、printやflushされた場合も無視する。

=back

=head2 METHODS

=over 4

=item flush

L<TL::Filter>参照

=item print

L<TL::Filter>参照

=back

=head1 SEE ALSO

=over 4

=item L<TL>

=item L<TL::Filter>

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
