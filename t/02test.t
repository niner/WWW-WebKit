use common::sense;
use Test::More;
use FindBin qw($Bin);

BEGIN {
    use_ok 'Test::WWW::WebKit';
}

my $sel = Test::WWW::WebKit->new();
ok($sel->init);

$sel->open_ok("$Bin/test/attribute.html");

$sel->refresh_ok;

done_testing;
