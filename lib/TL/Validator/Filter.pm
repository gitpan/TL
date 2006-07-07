# -----------------------------------------------------------------------------
# TL::Validator::Filter - Filterインターフェイス
# -----------------------------------------------------------------------------
use strict;
use warnings;

1;

package TL::Validator::Filter;
use TL;

#---------------------------------- 一般
sub new {
	my $class = shift;
	return bless {}, $class;
}

sub doFilter {
	die "call to abstract method";
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::CharLen - CharLenフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::CharLen;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isCharLen( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Email - Emailフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Email;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isEmail() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Enum - Enumフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Enum;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my @enum = split( /(?<!\\),/, $args );

	foreach (@enum) { $_ =~ s/\\,/,/g }

	return grep {
		my $value = $_;
		( grep { $_ eq $value } @enum ) == 0
	} @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::ExistentDay - ExistentDayフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::ExistentDay;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isExistentDay() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Gif - Gifフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Gif;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isGif() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Hira - Hiraフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Hira;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isHira() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::HtmlTag - HtmlTagフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::HtmlTag;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isHtmlTag() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::HttpsUrl - HttpsUrlフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::HttpsUrl;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isHttpsUrl() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::HttpUrl - HttpUrlフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::HttpUrl;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	if ( defined($args) && $args eq 's' ) {
		return grep {
			my $value = $TL->newValue($_);
			!( $value->isHttpUrl() || $value->isHttpsUrl() )
		} @$values;
	} else {
		return grep { !$TL->newValue($_)->isHttpUrl() } @$values;
	}
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Integer - Integerフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Integer;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isInteger( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Jpeg - Jpegフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Jpeg;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isJpeg() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Kata - Kataフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Kata;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isKata() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Len - Lenフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Len;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isLen( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::MobileEmail - MobileEmailフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::MobileEmail;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isMobileEmail() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::NotEmpty - NotEmptyフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::NotEmpty;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return @$values == 0 || grep { $TL->newValue($_)->isEmpty() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::NotWhitespace - NotWhitespaceフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::NotWhitespace;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { $TL->newValue($_)->isWhitespace() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Or - Orフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Or;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my $form = $TL->newForm( or => $values );
	my @filters =
	  ( $args =~ /((?:\w+)(?:\((?:.*?)\))?(?:\[(?:.*?)\])?)(?:\||$)/g );

	return (
		grep {
			my $validator = $TL->newValidator();
			$validator->addFilter( { or => $_ } );
			defined( $validator->check($form) )
		  } @filters
	) == @filters;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Password - Passwordフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Password;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isPassword() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Png - Pngフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Png;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isPng() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::PrintableAscii - PrintableAsciiフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::PrintableAscii;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isPrintableAscii() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Real - Realフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Real;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isReal( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::RegExp - RegExpフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::RegExp;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	return grep { $TL->newValue($_)->get() !~ /$args/ } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::SjisLen - SjisLenフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::SjisLen;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;
	my $args   = shift;

	my ( $min, $max ) =
	  defined($args) ? map { $_ ne '' ? $_ : undef } split( ',', $args ) : ();
	return grep { !$TL->newValue($_)->isSjisLen( $min, $max ) } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::TelNumber - TelNumberフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::TelNumber;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isTelNumber() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::TrailingSlash - TrailingSlashフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::TrailingSlash;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isTrailingSlash() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Portable - Portableフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Portable;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { $TL->newValue($_)->isUnportable() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::Wide - Wideフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::Wide;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isWide() } @$values;
}

# -----------------------------------------------------------------------------
# TL::Validator::Filter::ZipCode - ZipCodeフィルタ
# -----------------------------------------------------------------------------
package TL::Validator::Filter::ZipCode;
use TL;

use base qw{TL::Validator::Filter};

sub doFilter {
	my $this   = shift;
	my $values = shift;

	return grep { !$TL->newValue($_)->isZipCode() } @$values;
}

__END__

=encoding euc-jp

=head1 NAME

TL::Validator::Filter - TL::Validator filter I/F (ja)

=head1 NAME (ja)

TL::Validator::Filter::JA - TL::Validator フィルタ I/F

=head1 DESCRIPTION

L<TL::Validator> 参照

=head2 METHODS

=over 4

=item doFilter

内部メソッド

=item new

内部メソッド

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
