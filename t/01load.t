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

$sel->open("$Bin/test/drag_and_drop.html");
ok(1, 'opened');

$sel->native_drag_and_drop_to_object('id=dragme', 'id=target');

is($sel->resolve_locator('id=dragme')->get_parent_node->get_id, 'target');

$sel->refresh;

$sel->open("$Bin/test/attribute.html");
is($sel->get_attribute('id=test', 'class'), 'foo bar');

done_testing;
