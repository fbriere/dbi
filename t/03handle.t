#!perl -w

use strict;

use Test::More tests => 101;

## ----------------------------------------------------------------------------
## 03handle.t - tests handles
## ----------------------------------------------------------------------------
#
## ----------------------------------------------------------------------------

BEGIN { 
    use_ok( 'DBI' );
}

## ----------------------------------------------------------------------------
# get the Driver handle

my $driver = "ExampleP";

my $drh = DBI->install_driver($driver);
isa_ok( $drh, 'DBI::dr' );

SKIP: {
    skip "Kids attribute not supported under DBI::PurePerl", 1 if $DBI::PurePerl;
    
    cmp_ok($drh->{Kids}, '==', 0, '... this Driver does not yet have any Kids');
}

## ----------------------------------------------------------------------------
# do database handle tests inside do BLOCK to capture scope

do {
    my $dbh = DBI->connect("dbi:$driver:", '', '');
    isa_ok($dbh, 'DBI::db');
    
    SKIP: {
        skip "Kids and ActiveKids attributes not supported under DBI::PurePerl", 2 if $DBI::PurePerl;
    
        cmp_ok($drh->{Kids}, '==', 1, '... our Driver has one Kid');
        cmp_ok($drh->{ActiveKids}, '==', 1, '... our Driver has one ActiveKid');  
    }

    my $sql = "select name from ?";

    my $sth1 = $dbh->prepare_cached($sql);
    isa_ok($sth1, 'DBI::st');    
    ok($sth1->execute("."), '... execute ran successfully');

    my $ck = $dbh->{CachedKids};
    is(ref($ck), "HASH", '... we got the CachedKids hash');
    
    cmp_ok(scalar(keys(%{$ck})), '==', 1, '... there is one CachedKid');
    ok(eq_set(
        [ values %{$ck} ],
        [ $sth1 ]
        ), 
    '... our statment handle should be in the CachedKids');

    ok($sth1->{Active}, '... our first statment is Active');
    
    # use this to check that we are warned
    my $warn = 0;
    local $SIG{__WARN__} = sub { ++$warn if $_[0] =~ /still active/ };
    
    my $sth2 = $dbh->prepare_cached($sql);
    isa_ok($sth2, 'DBI::st');
    
    is($sth1, $sth2, '... prepare_cached returned the same statement handle');
    cmp_ok($warn,'==', 1, '... we got warned about our first statement handle being still active');
    
    ok(!$sth1->{Active}, '... our first statment is no longer Active since we re-prepared it');

    $sth2 = $dbh->prepare_cached($sql, { foo => 1 });
    isa_ok($sth2, 'DBI::st');
    
    isnt($sth1, $sth2, '... prepare_cached returned a different statement handle now');
    cmp_ok(scalar(keys(%{$ck})), '==', 2, '... there are two CachedKids');
    ok(eq_set(
        [ values %{$ck} ],
        [ $sth1, $sth2 ]
        ), 
    '... both statment handles should be in the CachedKids');    

    ok($sth1->execute("."), '... executing first statement handle again');
    ok($sth1->{Active}, '... first statement handle is now active again');
    
    my $sth3 = $dbh->prepare_cached($sql, undef, 3);
    isa_ok($sth3, 'DBI::st');
    
    isnt($sth1, $sth3, '... our new statement handle is not the same as our first');
    ok($sth1->{Active}, '... first statement handle is still active');
    
    cmp_ok(scalar(keys(%{$ck})), '==', 2, '... there are two CachedKids');    
    ok(eq_set(
        [ values %{$ck} ],
        [ $sth2, $sth3 ]
        ), 
    '... second and third statment handles should be in the CachedKids');      
    
    $sth1->finish;
    ok(!$sth1->{Active}, '... first statement handle is no longer active');    

    ok($sth3->execute("."), '... third statement handle executed properly');
    ok($sth3->{Active}, '... third statement handle is Active');
    
    my $sth4 = $dbh->prepare_cached($sql, undef, 1);
    isa_ok($sth4, 'DBI::st');
    
    is($sth4, $sth3, '... third statement handle and fourth one match');
    ok(!$sth3->{Active}, '... third statement handle is not Active');
    ok(!$sth4->{Active}, '... fourth statement handle is not Active (shouldnt be its the same as third)');
    
    cmp_ok(scalar(keys(%{$ck})), '==', 2, '... there are two CachedKids');    
    ok(eq_set(
        [ values %{$ck} ],
        [ $sth2, $sth4 ]
        ), 
    '... second and third/fourth statment handles should be in the CachedKids');     

    cmp_ok($warn, '==', 1, '... we still only got one warning');
    $dbh->disconnect;
    
    SKIP: {
        skip "Kids and ActiveKids attributes not supported under DBI::PurePerl", 2 if $DBI::PurePerl;
    
        cmp_ok($drh->{Kids}, '==', 1, '... our Driver has one Kid after disconnect');
        cmp_ok($drh->{ActiveKids}, '==', 0, '... our Driver has no ActiveKids after disconnect');      
    }
    
};


# make sure our driver has no more kids after this test
# NOTE:
# this also assures us that the next test has an empty slate as well
SKIP: {
    skip "Kids attribute not supported under DBI::PurePerl", 1 if $DBI::PurePerl;
    
    cmp_ok($drh->{Kids}, '==', 0, '... our Driver has no Kids after it was destoryed');
}

## ----------------------------------------------------------------------------
# handle reference leak tests

# NOTE: 
# this test checks for reference leaks by testing the Kids attribute
# which is not supported by DBI::PurePerl, so we just do not run this
# for DBI::PurePerl all together. Even though some of the tests would
# pass, it does not make sense becuase in the end, what is actually
# being tested for will give a false positive

sub work {
    my (%args) = @_;
    my $dbh = DBI->connect("dbi:$driver:", '', '');
    isa_ok( $dbh, 'DBI::db' );
    
    cmp_ok($drh->{Kids}, '==', 1, '... the Driver should have 1 Kid(s) now'); 
    
    if ( $args{Driver} ) {
        isa_ok( $dbh->{Driver}, 'DBI::dr' );
    } else {
        pass( "not testing Driver here" );
    }

    my $sth = $dbh->prepare_cached("select name from ?");
    isa_ok( $sth, 'DBI::st' );
    
    if ( $args{Database} ) {
        isa_ok( $sth->{Database}, 'DBI::db' );
    } else {
        pass( "not testing Database here" );
    }
    
    $dbh->disconnect;
    # both handles should be freed here
}

SKIP: {
    skip "Kids attribute not supported under DBI::PurePerl", 25 if $DBI::PurePerl;

    foreach my $args (
        {},
        { Driver   => 1 },
        { Database => 1 },
        { Driver   => 1, Database => 1 },
    ) {
        work( %{$args} );
        cmp_ok($drh->{Kids}, '==', 0, '... the Driver should have no Kids');
    }

    # make sure we have no kids when we end this
    cmp_ok($drh->{Kids}, '==', 0, '... the Driver should have no Kids at the end of this test');
}

## ----------------------------------------------------------------------------
# handle take_imp_data test

SKIP: {
    skip "take_imp_data test not supported under DBI::PurePerl", 12 if $DBI::PurePerl;

    my $dbh = DBI->connect("dbi:$driver:", '', '');
    isa_ok($dbh, "DBI::db");

    cmp_ok($drh->{Kids}, '==', 1, '... our Driver should have 1 Kid(s) here');

    my $imp_data = $dbh->take_imp_data;
    ok($imp_data, '... we got some imp_data to test');
    # generally length($imp_data) = 112 for 32bit, 116 for 64 bit
    # (as of DBI 1.37) but it can differ on some platforms
    # depending on structure packing by the compiler
    # so we just test that it's something reasonable:
    cmp_ok(length($imp_data), '>=', 80, '... test that our imp_data is greater than or equal to 80, this is reasonable');

    cmp_ok($drh->{Kids}, '==', 0, '... our Driver should have 0 Kid(s) after calling take_imp_data');

    {
        my $warn;
        local $SIG{__WARN__} = sub { ++$warn if $_[0] =~ /after take_imp_data/ };
        
        my $drh = $dbh->{Driver};
        ok(!defined $drh, '... our Driver should be undefined');
        
        my $trace_level = $dbh->{TraceLevel};
        ok(!defined $trace_level, '... our TraceLevel should be undefined');

        ok(!defined $dbh->disconnect, '... disconnect should return undef');

        ok(!defined $dbh->quote(42), '... quote should return undefined');

        cmp_ok($warn, '==', 4, '... we should have gotten 4 warnings');
    }

    my $dbh2 = DBI->connect("dbi:$driver:", '', '', { dbi_imp_data => $imp_data });
    isa_ok($dbh2, "DBI::db");
    # need a way to test dbi_imp_data has been used
    
    cmp_ok($drh->{Kids}, '==', 1, '... our Driver should have 1 Kid(s) again');
    
}

# we need this SKIP block on its own since we are testing the 
# destruction of objects within the scope of the above SKIP 
# block
SKIP: {
    skip "Kids attribute not supported under DBI::PurePerl", 1 if $DBI::PurePerl;
    
    cmp_ok($drh->{Kids}, '==', 0, '... our Driver has no Kids after this test');
}

## ----------------------------------------------------------------------------
# NullP statement handle attributes without execute

my $driver2 = "NullP";

my $drh2 = DBI->install_driver($driver);
isa_ok( $drh2, 'DBI::dr' );

SKIP: {
    skip "Kids attribute not supported under DBI::PurePerl", 1 if $DBI::PurePerl;
    
    cmp_ok($drh2->{Kids}, '==', 0, '... our Driver (2) has no Kids before this test');
}

do {
    my $dbh = DBI->connect("dbi:$driver2:", '', '');
    isa_ok($dbh, "DBI::db");

    my $sth = $dbh->prepare("foo bar");
    isa_ok($sth, "DBI::st");

    cmp_ok($sth->{NUM_OF_PARAMS}, '==', 0, '... NUM_OF_PARAMS is 0');
    ok(!defined $sth->{NUM_OF_FIELDS}, '... NUM_OF_FIELDS is undefined');
    is($sth->{Statement}, "foo bar", '... Statement is "foo bar"');

    ok(!defined $sth->{NAME},         '... NAME is undefined');
    ok(!defined $sth->{TYPE},         '... TYPE is undefined');
    ok(!defined $sth->{SCALE},        '... SCALE is undefined');
    ok(!defined $sth->{PRECISION},    '... PRECISION is undefined');
    ok(!defined $sth->{NULLABLE},     '... NULLABLE is undefined');
    ok(!defined $sth->{RowsInCache},  '... RowsInCache is undefined');
    ok(!defined $sth->{ParamValues},  '... ParamValues is undefined');
    # derived NAME attributes
    ok(!defined $sth->{NAME_uc},      '... NAME_uc is undefined');
    ok(!defined $sth->{NAME_lc},      '... NAME_lc is undefined');
    ok(!defined $sth->{NAME_hash},    '... NAME_hash is undefined');
    ok(!defined $sth->{NAME_uc_hash}, '... NAME_uc_hash is undefined');
    ok(!defined $sth->{NAME_lc_hash}, '... NAME_lc_hash is undefined');

    my $dbh_ref = ref($dbh);
    my $sth_ref = ref($sth);

    ok($dbh_ref->can("prepare"), '... $dbh can call "prepare"');
    ok(!$dbh_ref->can("nonesuch"), '... $dbh cannot call "nonesuch"');
    ok($sth_ref->can("execute"), '... $sth can call "execute"');

    # what is this test for??

    # I don't know why this warning has the "(perhaps ...)" suffix, it shouldn't:
    # Can't locate object method "nonesuch" via package "DBI::db" (perhaps you forgot to load "DBI::db"?)
    eval { ref($dbh)->nonesuch; };
};

SKIP: {
    skip "Kids attribute not supported under DBI::PurePerl", 1 if $DBI::PurePerl;
    
    cmp_ok($drh2->{Kids}, '==', 0, '... our Driver (2) has no Kids after this test');
}

## ----------------------------------------------------------------------------

1;
