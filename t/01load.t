use common::sense;
use Test::More tests => 2;

BEGIN {
    use_ok 'WWW::WebKit';
}

my $sel = WWW::WebKit->new(xvfb => 1);
ok($sel->init);
