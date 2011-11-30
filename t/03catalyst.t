use common::sense;
use Test::More;

use lib "t/lib";
use TestApp;

BEGIN {
    use_ok 'Test::WWW::WebKit::Catalyst';
}

my $sel = Test::WWW::WebKit::Catalyst->new(app => 'TestApp', xvfb => 1);
ok($sel->init, 'init');

$sel->open_ok("http://localhost:$ENV{CATALYST_PORT}/index");

done_testing;
