# -----------------------------------------------------------------------------
# TL::Filter::MobileHTML - 携帯電話向けHTML出力用フィルタ
# -----------------------------------------------------------------------------
package TL::Filter::MobileHTML;
use strict;
use warnings;
use TL;
require Unicode::Japanese;
require TL::Filter::HTML;
our @ISA = qw(TL::Filter::HTML);

# TL::Filter::MobileHTMLは、
# * 文字コードの変換をする
# * フォームへ"CCC=愛"を追加する
# * 外部リンクの書換えを *する*
# * セッションデータをリンク・フォームに追加 *する*
# * Content-Dispositionを出力しない

# オプション一覧:
# * charset     => 出力の文字コード。(UTF-8から変換される)
#                  常にUniJPを用いて変換される。
#                  デフォルト: Shift_JIS
# * contenttype => デフォルト: text/html; charset=(CHARSET)

1;

sub _new {
	my $class = shift;
	my $this = $class->SUPER::_new(@_);

	$this;
}

sub print {
	my $this = shift;
	my $data = shift;

	if(ref($data)) {
		die __PACKAGE__."#print, ARG[1] was a Ref. [$data]\n";
	}

	if(!$this->{content_printed}) {
		if(defined(&TL::Session::_getInstance)) {
			# TL::Sessionが有効になっているので、データが有れば、それを$this->{save}に加える。
			foreach my $group (TL::Session->_getInstanceGroups) {
				TL::Session->_getInstance($group)->_setSessionDataToForm($this->{save});
			}
		}
	}

	$this->SUPER::print($data);
}


sub _make_header {
	# TL::Filter::HTMLがクッキーを出力するのをやめさせる。
	return {};
}

__END__

=encoding utf-8

=head1 NAME

TL::Filter::MobileHTML - 携帯電話向けHTML出力用フィルタ

=head1 SYNOPSIS

  $TL->setContentFilter('TL::Filter::MobileHTML', charset => 'Shift_JIS');
  
  $TL->print($TL->readTextFile('foo.html'));

=head1 DESCRIPTION

HTMLに対して以下の処理を行う。

=over 4

=item 漢字コード変換（デフォルトShift_JIS、常にUnicode::Japaneseを使う）

=item ヘッダの管理

=item E<lt>form action=""E<gt> が空欄の場合、自分自身のCGI名を埋める

=item 特定フォームデータを指定された種別のリンクに付与する

=back

L<TL::Filter::HTML> との違いは以下の通り。

=over 4

=item 文字コード変換にEncodeを使わず、常にUnicode::Japaneseを使用。

=item セッション用のデータを全てのリンクに追記し、クッキーでの出力はしない。

=back

=head2 フィルタパラメータ

=over 4

=item charset

  $TL->setContentFilter('TL::Filter::MobileHTML', charset => 'Shift_JIS');

出力文字コードを指定する。省略可能。

使用可能なコードは次の通り。
UTF-8，Shift_JIS，EUC-JP，ISO-2022-JP
	
デフォルトはShift_JIS。

=item contenttype

  $TL->setContentFilter('TL::Filter::MobileHTML', contenttype => 'text/html; charset=sjis');

Content-Typeを指定する。省略可能。

デフォルトはtext/html; charset=（charasetで指定された文字コード）。

=item type

  $TL->setContentFilter('TL::Filter::MobileHTML', type => 'xhtml');

'html' もしくは 'xhtml' を利用可能。省略可能。

フィルタがHTMLを書換える際の動作を調整する為のオプション。
XHTMLを出力する際に、このパラメータをhtmlのままにした場合、
不正なXHTMLが出力される事がある。

デフォルトは 'html'。

=back

=head2 METHODS

=over 4

=item getSaveForm

  my $SAVE = $TL->getContentFilter->getSaveForm;

出力フィルタが所持している保存すべきデータが入った、
L<Form|TL::Form> オブジェクトを返す。

=item setDecideLink

  $TL->getContentFilter->setDecideLink(\&func);

リンク種別を決定する関数を設定する。
値を渡さないとデフォルトの判別処理に戻す。

関数の戻り値が1であれば、同じTLライブラリで作成された環境へのリンクとして、リンクの書き換えを行う。
関数の戻り値が0であれば、リンクの書き換えは行わない。 

デフォルトの判別処理は以下の関数で行っている。

  sub defaultDecideLink {
    my (%param) = @_;

    if($param{'link'} =~ m/^https?/) {
      return 0;
    }
    elsif($param{'link'} =~ m/^javascript/i) {
      return 0;
    }
    elsif($param{'link'} =~ m/^(?:mailto|ftp):/) {
      return 0;
    }
    elsif(not length $param{'link'}) {
      return 0;
    }
    else {
      return 1;
    }
  }

=item setHeader

  $TL->getContentFilter->setHeader($key => $value)

他の出力の前に実行する必要がある。

同じヘッダを既に出力しようとしていれば、そのヘッダの代わりに指定したヘッダを出力する。（上書きされる）

=item addHeader

  $TL->getContentFilter->addHeader($key => $value)

他の出力の前に実行する必要がある。

同じヘッダを既に出力しようとしていれば、そのヘッダに加えて指定したヘッダを出力する。（追加される）

=item print

L<TL::Filter>参照

=back

=head1 SEE ALSO

=over 4

=item L<TL>

=item L<TL::Filter>

=item L<TL::Filter::HTML>

=item L<TL::Form>

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
