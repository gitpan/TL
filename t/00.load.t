use Test::More tests => 1;

BEGIN {
    open INI, '>', "temp$$.ini";
    close INI;
    
    use_ok( 'TL', "temp$$.ini" );

    unlink "temp$$.ini";
}

diag( "Testing TL $TL::VERSION" );
