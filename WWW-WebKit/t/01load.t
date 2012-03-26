use common::sense;
use Test::More;
use FindBin qw($Bin);
use URI;

BEGIN {
    use_ok 'WWW::WebKit';
}

my $xvfb = 1;
my $sel = WWW::WebKit->new(xvfb => 1);
eval { $sel->init; };
if ($@ and $@ =~ /\ACould not start Xvfb/) {
    $sel = WWW::WebKit->new();
    $sel->init;
    $xvfb = 0;
}
ok(1, 'init done');

$sel->open("$Bin/test/load.html");
ok(1, 'opened');

is($sel->get_body_text, 'test');

$sel->open("$Bin/test/drag_and_drop.html");
ok(1, 'opened');

$sel->native_drag_and_drop_to_object('id=dragme', 'id=target');

SKIP: {
    skip 'drag and drop is not reliable without Xvfb', 1 unless $xvfb;
    is($sel->resolve_locator('id=dragme')->get_parent_node->get_id, 'target');
}

$sel->refresh;

$sel->open("$Bin/test/confirm.html");
is(pop @{ $sel->confirmations }, 'test');
is($sel->get_text('id=result'), 'yes');

$sel->answer_on_next_prompt('test');
#$sel->open("$Bin/test/prompt.html");
#is($sel->get_text('id=result'), 'yes');

$sel->open("$Bin/test/attribute.html");
is($sel->get_attribute('id=test@class'), 'foo bar');

is($sel->is_visible('id=test'), 1, 'test visible');
is($sel->is_visible('id=invisible'), 0, 'invisible');
is($sel->is_visible('id=invisible_child'), 0, 'child invisible');
is($sel->is_visible('id=void'), 0, 'display none');
is($sel->is_visible('id=void_child'), 0, 'child display none');

$sel->open("$Bin/test/key_press.html");
$sel->key_press('css=body', '\027');
$sel->pause(200);
is(pop @{ $sel->alerts }, 27);
$sel->key_press('css=body', '\013');
$sel->pause(200);
is(pop @{ $sel->alerts }, 13);
$sel->key_press('css=body', 'a');
$sel->pause(200);
is(pop @{ $sel->alerts }, 65);

$sel->open("$Bin/test/eval.html");
is($sel->eval_js('"foo"'), 'foo');
is($sel->eval_js('document.getElementById("foo").firstChild.data'), 'bar');

$sel->open("$Bin/test/type.html");
$sel->type('id=foo', 'bar');
$sel->click('id=submit');
$sel->wait_for_page_to_load;
is(URI->new($sel->view->get_uri)->query, 'foo=bar');

$sel->open("$Bin/test/select.html");
$sel->select('id=test', 'value=1');
is(pop @{ $sel->alerts }, 'onchange fired');
$sel->select('id=test_event', 'value=1');
is(pop @{ $sel->alerts }, 'change event fired');

done_testing;
