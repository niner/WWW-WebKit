use common::sense;
use Test::More;
use FindBin qw($Bin);

BEGIN {
    use_ok 'WWW::WebKit';
}

my $sel = WWW::WebKit->new(xvfb => 1);
ok($sel->init);

$sel->open("$Bin/test/load.html");
ok(1, 'opened');

is($sel->get_body_text, 'test');

done_testing;
