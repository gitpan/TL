# -----------------------------------------------------------------------------
# TL::Sendmail::Esmtp - Forcast esmtpを使用するメール送信
# -----------------------------------------------------------------------------
package TL::Sendmail::Esmtp;
use strict;
use warnings;
use TL;
require TL::Sendmail;
our @ISA = qw(TL::Sendmail);

1;

sub _new {
	my $class = shift;
	my $group = shift;
	my $this = bless {} => $class;

	$this->{group} = $group;
	$this->{dbgroup} or die __PACKAGE__."#new, dbgroup is not set.\n";

	$this->{resend} = $TL->INI->get($group => reset, 1);
	$this->{resendlimit} = $TL->INI->get($group => resendlimit, '24 hours');

	$this;
}

sub send {
	my $this = shift;
	my $data = $this->_getoptSend(@_);

	my $DB = $TL->getDB($this->{dbgroup});

	foreach my $rcpt (@{$data->{rcpt}}) {
		$DB->execute(
			q{
				INSERT INTO mailsend
					(start, resend, mailfrom, rcptto, hourlimit, resendlimit, data)
				VALUES (NOW(), ?     , ?       , ?     , ''       , ?          , ?   )
			},
			$this->{resend} ? 'yes' : 'no',
			$data->{from},
			$rcpt,
			$TL->parsePeriod($this->{resendlimit}),
			$data->{data},
		);
	}

	$this;
}


__END__

=encoding utf-8

=head1 NAME

TL::Sendmail::Esmtp - Mail Sending that uses Forcast esmtp (ja)

=head1 NAME (ja)

TL::Sendmail::Esmtp::JA - Forcast esmtpを使用するメール送信

=head1 DESCRIPTION

  ！！注意！！
  このクラスを利用するにはEsmtpが必要です。
  Esmtpとは、ユミルリンク株式会社が販売している高速メール配信システムです。


esmtpを用いてメールを送信する。

このクラスを使用する場合は、事前にesmtp用テーブル群を
用意しておかなければならない。

また、このクラスはesmtpプロセスが起動しているかどうかを関知しない。

=head2 METHODS

=over 4

=item new

L<TL::Sendmail> 参照。

=item connect

=item disconnect

=item setTimeout

何もしない。

=item send

L<TL::Sendmail> 参照。

=back


=head2 Ini パラメータ

=over 4

=item dbgroup

  dbgroup = DB

使用するDBグループ名。
L<ini|TL::Ini> で設定したグループ名を渡す。
L<TL#startCgi|TL/"startCgi"> で有効化しなければならない。

=item resend

  reset = 1

送信失敗時に再送するかどうか。省略可能。
0の場合、再送しない。
1の場合、再送する。

デフォルトは1。

=item resendlimit

  resendlimit = 3 days

再送に成功しない場合に、それを打ち切るまでの時間。
0を指定した場合は永久に打ち切らない。L<度量衡|TL/"度量衡"> 参照。省略可能。

デフォルトは '24 hours'。

=back


=head1 SEE ALSO

=over 4

=item L<TL>

=item L<TL::Sendmail>

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

