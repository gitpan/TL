# -----------------------------------------------------------------------------
# TL::Sendmail - メールの送信を行う
# -----------------------------------------------------------------------------
package TL::Sendmail;
use strict;
use warnings;
use TL;

1;

sub _new {
	my $class = shift;
	my $group = shift;

	$group = defined $group ? $group : 'Sendmail';

	# iniのmethodパラメータに応じて実際のクラスのインスタンスを作る。
	my $method = $TL->INI->get($group => 'method');
	if(!defined($method)) {
		$method = 'smtp';
	}

	if($method eq 'smtp') {
		require TL::Sendmail::Smtp;
		TL::Sendmail::Smtp->_new($group);
	} elsif($method eq 'mailqueue') {
		require TL::Sendmail::MailQueue;
		TL::Sendmail::MailQueue->_new($group);
	} elsif($method eq 'esmtp') {
		require TL::Sendmail::Esmtp;
		TL::Sendmail::Esmtp->_new($group);
	} else {
		die "TL#newSendmail, ini.method was invalid. [$method]\n";
	}
}

sub setTimeout {
	# デフォルトの実装では何もしない
}

sub connect {
	# デフォルトの実装では何もしない
}

sub disconnect {
	# デフォルトの実装では何もしない
}

sub send {
	# オーバーライドしなければエラー
	die __PACKAGE__."#send, internal error: this method has to be overridden.\n";
}

sub _setLogging {
	# デフォルトの実装では何もしない
	# TL内部でのエラー処理用に、ログ保存のオプションを変更したいときに呼び出される。
	# iniファイルのloggingよりこちらの指定を優先しなければならない。
}

sub _getoptSend {
	my $this = shift;
	my $pkg = ref($this);

	my $data = do {
		my %hash = @_;
		%hash = map {
			my $key = $_;
			my $val = $hash{$key};

			$key =~ s/^-//;
			$key => $val;
		} keys %hash;
			\%hash;
	};

	if(!defined($data->{data})) {
		die "$pkg#send, ARG[data] was undef.\n";
	}

	if(!defined($data->{from}) || !defined($data->{rcpt})) {
		# 省略されているので本文から読み出す

		local *addr = sub {
			my $str = shift;
			defined $str or return undef;

			$str =~ s/^\s*|\s*$//g;

			if($str =~ m/<(.+?)>\s*$/) {
				$1;
			} else {
				$str;
			}
		};

		my $mail = $TL->newMail->set($data->{data});
		$data->{from} = addr($mail->getHeader('From'));
		$data->{rcpt} = addr($mail->getHeader('to'));
	}

	if(!defined($data->{from})) {
		die "$pkg#send, ARG[from] was undef and not readable from the data.\n";
	}
	if(!defined($data->{rcpt})) {
		die "$pkg#send, ARG[rcpt] was undef and not readable from the data.\n";
	}

	if(ref($data->{rcpt}) ne 'ARRAY') {
		$data->{rcpt} = [ $data->{rcpt} ];
	}

	$data;
}


__END__

=encoding utf-8

=head1 NAME

TL::Sendmail - メールの送信を行う

=head1 SYNOPSIS

  my $sendmail = $TL->newSendmail
    ->connect
    ->send(
        -from => 'null@example.org',
	-rcpt => 'null@example.org',
	-data => '.....',
       )
    ->disconnect;

=head1 DESCRIPTION

=head2 METHODS

=over 4

=item $TL->newSendmail

  $TL->newSendmail($inigroup);

TL::Sendmail オブジェクトを作成。
引数には L<ini|TL::Ini> で設定したグループ名を渡す。
引数省略時は 'Sendmail' グループが使用される。

=item setTimeout

  $smail->setTimeout($sec);

タイムアウトまでの秒数を設定する。
引数については L<TL::Sendmail::Smtp>、L<TL::Sendmail::MailQueue>、L<TL::Sendmail::Esmtp> を参照。

=item connect

  $smail->connect;

メール送信先に接続を行い、sendメソッドの準備を整える。
引数については L<TL::Sendmail::Smtp>、L<TL::Sendmail::MailQueue>、L<TL::Sendmail::Esmtp> を参照。

=item disconnect

  $smail->disconnect;

メール送信先との接続を切断する。

=item send

  $smail->send(-from => $from, -rcpt => $rcpt,       -data => $data)
  $smail->send(-from => $from, -rcpt => [$rcpt,...], -data => $data)

-from、-rcpt を省略した場合は、-dataのヘッダから宛先を抽出し、送信する。
connectの後に呼ばなければならないが、複数回呼び出すことが出来る。
sendメソッドを使用した後は、disconnectしなければならない。

=back


=head2 Ini パラメータ

=over 4

=item method

  method = smtp

送信メソッドを指定する。省略可能。
指定可能なメソッドはsmtp、mailqueue、 esmtp の３種類。

デフォルトはsmtp。

=item logging

  logging = 1

ログの取得の可否を指定する。省略可能。
0の場合、ログを取得しない。
1の場合、ログを取得する。

デフォルトは0。

=item その他パラメータ

各送信メソッドのクラスの L<ini|TL::Ini> パラメータの項を参照。 

=back


=head2 送信メソッド一覧

=over 4

=item L<TL::Sendmail::Smtp> - SMTP送信

=item L<TL::Sendmail::MailQueue> - Lib7用メールキュー

=item L<TL::Sendmail::Esmtp> - Forcast esmtp

=back


=head1 SEE ALSO

=over 4

=item L<TL>

=item L<TL::Mail>

=item L<TL::HtmlMail>

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
