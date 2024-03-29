use strict;
use warnings;
use ExtUtils::MakeMaker;

my $OPENSSL_LIBS = $ENV{LDFLAGS} || '';
my $OPENSSL_CFLAGS = $ENV{CFLAGS} || '';

WriteMakefile(
    NAME                => 'TL::SMIME',
    AUTHOR              => 'Ymirlink <null@ymir.jp>',
    VERSION_FROM        => 'SMIME.pm',
    ABSTRACT_FROM       => 'SMIME.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    LIBS                => ["$OPENSSL_LIBS -lcrypto"],
    INC                 => "$OPENSSL_CFLAGS",
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'TL-SMIME-*' },
);
