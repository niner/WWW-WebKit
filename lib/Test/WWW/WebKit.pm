package Test::WWW::WebKit;

use 5.10.0;
use Moose;

extends 'WWW::WebKit';

use Glib qw(TRUE FALSE);
use Time::HiRes qw(time usleep);
use Test::More;

sub open_ok {
    my ($self, $url) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->open($url);

    ok(1, "open_ok($url)");
}

sub refresh_ok {
    my ($self) = @_;

    $self->refresh;
    ok(1, "refresh_ok()");
}

sub select_ok {
    my ($self, $select, $option) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->select($select, $option), "select_ok($select, $option)");
}

sub click_ok {
    my ($self, $locator) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->click($locator), "click_ok($locator)");
}

sub wait_for_page_to_load_ok {
    my ($self, $timeout) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->wait_for_page_to_load($timeout);
}

sub wait_for_element_present_ok {
    my ($self, $locator, $timeout) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $timeout ||= $self->default_timeout;

    ok($self->wait_for_element_present($locator, $timeout), "wait_for_element_present_ok($locator, $timeout)");
}

sub is_element_present_ok {
    my ($self, $locator) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->is_element_present($locator), "is_element_present_ok($locator)");
}

sub type_ok {
    my ($self, $locator, $text) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok(eval { $self->type($locator, $text) }, "type_ok($locator, $text)");
}

sub type_keys_ok {
    my ($self, $locator, $text) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok(eval { $self->type_keys($locator, $text) }, "type_keys_ok($locator, $text)");
}

sub is_ordered_ok {
    my ($self, $first, $second) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->is_ordered($first, $second), "is_ordered_ok($first, $second)");
}

sub mouse_over_ok {
    my ($self, $locator) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->mouse_over($locator), "mouse_over_ok($locator)");
}

sub mouse_down_ok {
    my ($self, $locator) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->mouse_down($locator), "mouse_down_ok($locator)");
}

sub fire_event_ok {
    my ($self, $locator, $event_type) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->fire_event($locator, $event_type), "fire_event_ok($locator, $event_type)");
}

sub text_is {
    my ($self, $locator, $text) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is($self->get_text($locator), $text);
}

sub text_like {
    my ($self, $locator, $text) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    like($self->get_text($locator), $text);
}

sub value_is {
    my ($self, $locator, $value) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is($self->get_value($locator), $value, "value_is($locator, $value)");
}

sub is_visible_ok {
    my ($self, $locator) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->is_visible($locator), "is_visible($locator)");
}

sub submit_ok {
    my ($self, $locator) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    ok($self->submit($locator), "submit_ok($locator)");
}

=head2 native_drag_and_drop_to_object_ok($source, $target)

drag&drop test that works with native HTML5 D&D events.

=cut

sub native_drag_and_drop_to_object_ok {
    my ($self, $source, $target) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->native_drag_and_drop_to_object($source, $target);

    ok(1, "native_drag_and_drop_to_object_ok($source, $target)");
}

1;
