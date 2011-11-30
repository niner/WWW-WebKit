use common::sense;
use Test::More tests => 2;

BEGIN {
    use_ok 'Test::WWW::WebKit';
}

my $sel = Test::WWW::WebKit->new();
ok($sel->init);

