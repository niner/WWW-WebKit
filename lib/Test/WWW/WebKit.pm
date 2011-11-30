package Test::WWW::WebKit;

use 5.10.0;
use Moose;

extends 'WWW::WebKit';

use Glib qw(TRUE FALSE);
use Time::HiRes qw(time usleep);
use Test::More;

sub open_ok {
    my ($self, $url) = @_;

    $self->open($url);

    ok(1, "open_ok($url)");
}

sub select_ok {
    my ($self, $select, $option) = @_;

    ok($self->select($select, $option), "select_ok($select, $option)");
}

sub click_ok {
    my ($self, $locator) = @_;

    ok($self->click($locator), "click_ok($locator)");
}

sub wait_for_page_to_load_ok {
    my ($self, $timeout) = @_;

    $self->wait_for_page_to_load($timeout);
}

sub wait_for_element_present_ok {
    my ($self, $locator, $timeout) = @_;
    $timeout ||= $self->default_timeout;

    ok($self->wait_for_element_present($locator, $timeout), "wait_for_element_present_ok($locator, $timeout)");
}

sub is_element_present_ok {
    my ($self, $locator) = @_;

    ok($self->is_element_present($locator), "is_element_present_ok($locator)");
}

sub type_ok {
    my ($self, $locator, $text) = @_;

    ok(eval { $self->type($locator, $text) }, "type_ok($locator, $text)");
}

sub is_ordered_ok {
    my ($self, $first, $second) = @_;

    ok($self->is_ordered($first, $second), "is_ordered_ok($first, $second)");
}

sub mouse_over_ok {
    my ($self, $locator) = @_;

    ok($self->mouse_over($locator), "mouse_over_ok($locator)");
}

=head2 native_drag_and_drop_to_object_ok($source, $target)

drag&drop test that works with native HTML5 D&D events.

=cut

sub native_drag_and_drop_to_object_ok {
    my ($self, $source, $target) = @_;

    $self->native_drag_and_drop_to_object($source, $target);

    ok(1, "native_drag_and_drop_to_object_ok($source, $target)");
}

1;
