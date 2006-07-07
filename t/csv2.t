use Test::More;
use Test::Exception tests => 1;

use strict;
use warnings;

BEGIN {
    open INI, '>', "tmp$$.ini";
    close INI;
    
    eval q{use TL qw("tmp$$.ini")};
}

END {
    unlink "tmp$$.ini";
}

require TL::CSV;
	dies_ok {delete $INC{"Text/CSV_XS.pm"};local(@INC);TL::CSV->_new;}
