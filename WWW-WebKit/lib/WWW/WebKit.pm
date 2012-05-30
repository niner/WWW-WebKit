package WWW::WebKit;

=head1 NAME

WWW::WebKit - Perl extension for controlling an embedding WebKit engine

=head1 SYNOPSIS

    use WWW::WebKit;

    my $webkit = WWW::WebKit->new(xvfb => 1);
    $webkit->init;

    $webkit->open("http://www.google.com");
    $webkit->type("q", "hello world");
    $webkit->click("btnG");
    $webkit->wait_for_page_to_load(5000);
    print $webkit->get_title;

=head1 DESCRIPTION

WWW::WebKit is a drop-in replacement for WWW::Selenium using Gtk3::WebKit as browser instead of relying on an external Java server and an installed browser.

=head2 EXPORT

None by default.

=cut

use 5.10.0;
use Moose;

use Gtk3;
use Gtk3::WebKit;
use Glib qw(TRUE FALSE);
use Time::HiRes qw(time usleep);
use X11::Xlib;
use Carp qw(carp croak);
use XSLoader;

our $VERSION = '0.03';

use constant DOM_TYPE_ELEMENT => 1;
use constant ORDERED_NODE_SNAPSHOT_TYPE => 7;

XSLoader::load(__PACKAGE__, $VERSION);

has xvfb => (
    is  => 'ro',
    isa => 'Bool',
);

has view => (
    is      => 'ro',
    isa     => 'Gtk3::WebKit::WebView',
    lazy    => 1,
    default => sub {
        Gtk3::WebKit::WebView->new
    },
);

has window => (
    is      => 'ro',
    isa     => 'Gtk3::Window',
    lazy    => 1,
    default => sub {
        my ($self) = @_;
        my $sw = Gtk3::ScrolledWindow->new;
        $sw->add($self->view);

        my $win = Gtk3::Window->new;
        $win->set_default_size(1600, 1200);
        $win->add($sw);
        return $win;
    }
);

has alerts => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has confirmations => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has prompt_answers => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has console_messages => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has print_requests => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has default_timeout => (
    is      => 'rw',
    isa     => 'Int',
    default => 30_000,
);

has xvfb_pid => (
    is  => 'rw',
    isa => 'Int',
);

has xvfb_server => (
    is => 'rw',
);

has modifiers => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { {control => 0} },
);

=head3 init

Initializes Webkit and GTK3. Must be called before any of the other methods.

=cut

sub init {
    my ($self) = @_;

    $self->setup_xvfb if $self->xvfb;

    Gtk3::init;

    $self->view->signal_connect('script-alert' => sub {
        push @{ $self->alerts }, $_[2];
        return TRUE;
    });
    $self->view->signal_connect('script-confirm' => sub {
        push @{ $self->confirmations }, $_[2];
        WWW::WebKit::XSHelper::set_int_return_value($_[3], TRUE);
        return TRUE;
    });
    $self->view->signal_connect('script-prompt' => sub {
        # warn 'prompt: ' . $_[2];
        # warn "answering with: " . $self->prompt_answers->[-1];
        #FIXME causes segfault:
        #WWW::WebKit::XSHelper::set_string_return_value($_[4], pop @{ $self->prompt_answers });
        return TRUE;
    });
    $self->view->signal_connect('console-message' => sub {
        push @{ $self->console_messages }, $_[1];
        return FALSE;
    });
    $self->view->signal_connect('print-requested' => sub {
        push @{ $self->print_requests }, $_[1];
        return TRUE;
    });

    $self->window->show_all;
    Gtk3->main_iteration while Gtk3->events_pending;

    return $self;
}

sub setup_xvfb {
    my ($self) = @_;

    open my $stderr, '>&', \*STDERR or die "Can't dup STDERR: $!";
    close STDERR;

    if (system('Xvfb -help') != 0) {
        open STDERR, '>&', $stderr;
        die 'Could not start Xvfb';
    }

    my ($server, $display);
    while (1) {
        $display = 1 + int(rand(98));

        last if $self->xvfb_pid(open $server, '|-', "Xvfb :$display -screen 0 1600x1200x24");
    }

    open STDERR, '>&', $stderr;

    sleep 1;
    $self->xvfb_server($server);
    $ENV{DISPLAY} = ":$display";
}

sub DESTROY {
    my ($self) = @_;
    return unless $self->xvfb_pid;

    kill 15, $self->xvfb_pid;
}

=head2 Implemented methods of the Selenium API

Please see L<WWW::Selenium> for the full documentation of these methods.

=head3 set_timeout($timeout)

Set the default timeout to $timeout.

=cut

sub set_timeout {
    my ($self, $timeout) = @_;

    $self->default_timeout($timeout);
}

=head3 open($url)

=cut

sub open {
    my ($self, $url) = @_;

    $self->view->open($url);

    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
}

=head3 refresh()

=cut

sub refresh {
    my ($self) = @_;

    $self->view->reload;
    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
}

=head3 go_back()

=cut

sub go_back {
    my ($self) = @_;

    $self->view->go_back;
    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
}

sub eval_js {
    my ($self, $js) = @_;

    $js =~ s/'/\\'/g;
    $self->view->execute_script("alert(eval('$js'));");
    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
    return pop @{ $self->alerts };
}

sub code_for_locator {
    my ($self, $locator, $context) = @_;

    $context ||= 'document';

    if ($locator =~ /^xpath=(.*)/) {
        return "document.evaluate('$1', $context, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue";
    }
    if ($locator =~ /^label=(.*)/) {
        return $self->code_for_locator(qq{xpath=.//*[text()="$1"]}, $context);
    }
    if ($locator =~ /^id=(.*)/) {
        return "document.getElementById('$1')";
    }
    die "unknown locator $locator";
}

sub resolve_locator {
    my ($self, $locator, $document, $context) = @_;

    carp "got no locator" unless $locator;

    $document ||= $self->view->get_dom_document;
    $context ||= $document;

    if (my ($label) = $locator =~ /^label=(.*)/) {
        return $self->resolve_locator($label eq '' ? qq{xpath=.//*[not(text())]} : qq{xpath=.//*[text()="$label"]}, $document, $context);
    }
    elsif (my ($link) = $locator =~ /^link=(.*)/) {
        return $self->resolve_locator($link eq '' ? qq{xpath=.//a[not(descendant-or-self::text())]} : qq{xpath=.//a[descendant-or-self::text()="$link"]}, $document, $context);
    }
    elsif (my ($value) = $locator =~ /^value=(.*)/) {
        return $self->resolve_locator(qq{xpath=.//*[\@value="$value"]}, $document, $context);
    }
    elsif (my ($index) = $locator =~ /^index=(.*)/) {
        return $self->resolve_locator(qq{xpath=.//option[position()="$index"]}, $document, $context);
    }
    elsif (my ($id) = $locator =~ /^id=(.*)/) {
        return $document->get_element_by_id($id);
    }
    elsif (my ($css) = $locator =~ /^css=(.*)/) {
        return $document->query_selector($css);
    }
    elsif (my ($class) = $locator =~ /^class=(.*)/) {
        return $document->query_selector(".$class");
    }
    elsif (my ($name) = $locator =~ /^name=(.*)/) {
        return $self->resolve_locator(qq{xpath=.//*[\@name="$name"]}, $document, $context);
    }
    elsif (my ($xpath) = $locator =~ /^(?: xpath=)?(.*)/xm) {
        my $resolver = $document->create_ns_resolver($context);
        my $xpath_results = $document->evaluate($xpath, $context, $resolver, ORDERED_NODE_SNAPSHOT_TYPE, undef);
        my $length = $xpath_results->get_snapshot_length;
        croak "$xpath gave $length results: " . join(', ', map $xpath_results->snapshot_item($_), 0 .. $length - 1) if $length != 1;
        return $xpath_results->snapshot_item(0);
    }

    carp "unknown locator $locator";
    die "unknown locator $locator";
}

=head3 get_xpath_count

=cut

sub get_xpath_count {
    my ($self, $xpath) = @_;

    my $document = $self->view->get_dom_document;
    my $resolver = $document->create_ns_resolver($document);
    my $xpath_results = $document->evaluate($xpath, $document, $resolver, ORDERED_NODE_SNAPSHOT_TYPE, undef);
    return $xpath_results->get_snapshot_length;
}

=head3 select($select, $option)

=cut

sub select {
    my ($self, $select, $option) = @_;

    my $document = $self->view->get_dom_document;
    $select = $self->resolve_locator($select, $document)          or return;
    $option = $self->resolve_locator($option, $document, $select) or return;

    my $options = $select->get_property('options');
    foreach my $i (0 .. $options->get_length) {
        my $current = $options->item($i);

        if ($current->is_same_node($option)) {
            $select->set_selected_index($i);

            my $changed = $document->create_event('Event');
            $changed->init_event('change', TRUE, TRUE);
            $select->dispatch_event($changed);

            Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
            return 1;
        }
    }

    return;
}

=head3 click($locator)

=cut

sub click {
    my ($self, $locator) = @_;

    my $document = $self->view->get_dom_document;
    my $target = $self->resolve_locator($locator, $document) or return;

    my $click = $document->create_event('MouseEvent');
    my ($x, $y) = $self->get_center_screen_position($target);
    $click->init_mouse_event('click', TRUE, TRUE, $document->get_property('default_view'), 1, $x, $y, $x, $y, FALSE, FALSE, FALSE, FALSE, 0, $target);
    $target->dispatch_event($click);
    return 1;
}

=head3 check($locator)

=cut

sub check {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);
    return $self->change_check($element, 1);

    return;
}

=head3 uncheck($locator)

=cut

sub uncheck {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);
    return $self->change_check($element, undef);

    return;
}

sub change_check {
    my ($self, $element, $set_checked) = @_;

    my $document = $self->view->get_dom_document;

    unless ($set_checked) {
        $element->remove_attribute('checked');
    }
    else {
        $element->set_attribute('checked', 'checked');
    }

    my $changed = $document->create_event('Event');
    $changed->init_event('change', TRUE, TRUE);
    $element->dispatch_event($changed);

    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
    return 1;
}

=head3 wait_for_page_to_load($timeout)

=cut

sub wait_for_page_to_load {
    my ($self, $timeout) = @_;

    #TODO implement timeout
    $self->pause(300);
    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
}

=head3 wait_for_element_present($locator, $timeout)

=cut

sub wait_for_element_present {
    my ($self, $locator, $timeout) = @_;
    $timeout ||= $self->default_timeout;

    my $element;
    my $expiry = time + $timeout / 1000;

    while (1) {
        Gtk3->main_iteration while Gtk3->events_pending;

        last if $element = $self->is_element_present($locator);
        last if time > $expiry;
        usleep 10000;
    }

    return $element;
}

=head3 is_element_present($locator)

=cut

sub is_element_present {
    my ($self, $locator) = @_;

    return eval { $self->resolve_locator($locator) };
}

=head3 get_text($locator)

=cut

sub get_text {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator) or croak "Element not found in get_text($locator)";
    my $value = $element->get_text_content;
    $value =~ s/\A \s+ | \s+ \z//gxm;
    $value =~ s/\s+/ /gxms; # squeeze white space
    return $value;
}

=head3 type($locator, $text)

=cut

sub type {
    my ($self, $locator, $text) = @_;

    $self->resolve_locator($locator)->set_value($text);

    return 1;
}

my %keycodes = (
    '\013' => 36,
    '\027' => 9,
);

sub key_press {
    my ($self, $locator, $key, $elem) = @_;
    my $display = X11::Xlib->new;

    my $keycode = exists $keycodes{$key} ? $keycodes{$key} : $display->XKeysymToKeycode(X11::Xlib::XStringToKeysym($key));

    $elem ||= $self->resolve_locator($locator) or return;
    $elem->focus;

    $display->XTestFakeKeyEvent($keycode, 1, 1);
    $display->XTestFakeKeyEvent($keycode, 0, 1);
    $display->XFlush;

    # Unfortunately just does nothing:
    #Gtk3::test_widget_send_key($self->view, int($key), 'GDK_MODIFIER_MASK');

    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';

    return 1;
}

=head3 type_keys($locator, $string)

=cut

sub type_keys {
    my ($self, $locator, $string) = @_;

    my $element = $self->resolve_locator($locator) or return;

    foreach (split //, $string) {
        $self->key_press($locator, $_, $element) or return;
    }

    return 1;
}

sub control_key_down {
    my ($self) = @_;

    $self->modifiers->{control} = 1;
}

sub control_key_up {
    my ($self) = @_;

    $self->modifiers->{control} = 0;
}

=head3 pause($time)

=cut

sub pause {
    my ($self, $time) = @_;

    my $expiry = time + $time / 1000;

    while (1) {
        Gtk3->main_iteration while Gtk3->events_pending;

        if (time < $expiry) {
            usleep 10000;
        }
        else {
            last;
        }
    }
}

=head3 is_ordered($first, $second)

=cut

sub is_ordered {
    my ($self, $first, $second) = @_;
    return $self->resolve_locator($first)->compare_document_position($self->resolve_locator($second)) == 4;
}

=head3 get_body_text()

=cut

sub get_body_text {
    my ($self) = @_;

    return $self->get_text('xpath=//body');
}

=head3 get_title()

=cut

sub get_title {
    my ($self) = @_;

    return $self->get_text('xpath=//title');
}

=head3 mouse_over($locator)

=cut

sub mouse_over {
    my ($self, $locator) = @_;

    my $document = $self->view->get_dom_document;
    my $target = $self->resolve_locator($locator, $document) or return;

    my $move = $document->create_event('MouseEvent');
    $move->init_mouse_event('mouseover', TRUE, TRUE, $document->get_property('default_view'), 1, 0, 0, 0, 0, FALSE, FALSE, FALSE, FALSE, 0, $target);
    $target->dispatch_event($move);

    return 1;
}

=head3 mouse_down($locator)

=cut

sub mouse_down {
    my ($self, $locator) = @_;

    my $document = $self->view->get_dom_document;
    my $target = $self->resolve_locator($locator, $document) or return;

    my $click = $document->create_event('MouseEvent');
    $click->init_mouse_event('mousedown', TRUE, TRUE, $document->get_property('default_view'), 1, 0, 0, 0, 0, $self->modifiers->{control} ? TRUE : FALSE, FALSE, FALSE, FALSE, 0, $target);
    $target->dispatch_event($click);
    return 1;
}

=head3 fire_event($locator, $event_type)

=cut

sub fire_event {
    my ($self, $locator, $event_type) = @_;

    my $document = $self->view->get_dom_document;
    my $target = $self->resolve_locator($locator, $document) or return;

    my $event = $document->create_event('HTMLEvents');
    $event->init_event($event_type, TRUE, TRUE);
    $target->dispatch_event($event);

    return 1;
}

=head3 get_value($locator)

=cut

sub get_value {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator);

    if (lc $element->get_node_name eq 'input' and $element->get_property('type') ~~ [qw(checkbox radio)]) {
        return $element->get_checked ? 'on' : 'off';
    }
    else {
        my $value = $element->get_value;
        $value =~ s/\A \s+ | \s+ \z//gxm;
        return $value;
    }
}

=head3 get_attribute($locator)

=cut

sub get_attribute {
    my ($self, $locator) = @_;
    ($locator, my $attr) = $locator =~ m!\A (.*?) /?@ ([^@]*) \z!xm;

    return $self->resolve_locator($locator)->get_attribute($attr);
}

=head3 is_visible($locator)

=cut

sub is_visible {
    my ($self, $locator) = @_;

    my $element = $self->resolve_locator($locator) or croak "element not found: $locator";

    my $view = $self->view->get_dom_document->get_property('default_view');
    my $style = $view->get_computed_style($element, '');

    # visibility can be calculated by using CSS inheritance. A child of a invisbile parent can still be visible!
    my $visible = $style->get_property_value('visibility') eq 'hidden' ? 0 : 1;

    do {
        $style = $view->get_computed_style($element, '');
        $visible &&= $style->get_property_value('display') eq 'none' ? 0 : 1;
    } while ($visible and $element = $element->get_parent_node);

    return $visible;
}

=head3 submit($locator)

=cut

sub submit {
    my ($self, $locator) = @_;

    my $form = $self->resolve_locator($locator) or return;
    $form->submit;

    return 1;
}

=head3 get_html_source()

=cut

sub get_html_source {
    my ($self) = @_;

    my $data = $self->view->get_main_frame->get_data_source->get_data;
    return $data->{str} if ref $data;
    return $data;
}

=head3 get_confirmation()

=cut

sub get_confirmation {
    my ($self) = @_;

    return pop @{ $self->confirmations };
}

=head3 print_requested()

=cut

sub print_requested {
    my ($self) = @_;

    return pop @{ $self->print_requests } ? 1 : 0;
}

=head3 answer_on_next_prompt($answer)

=cut

sub answer_on_next_prompt {
    my ($self, $answer) = @_;

    push @{ $self->prompt_answers }, $answer;
}

=head2 Additions to the Selenium API

=head3 wait_for_element_to_disappear($locator, $timeout)

Works just like wait_for_element_present but instead of waiting for the element to appear, it waits for the element to disappear.

=cut

sub wait_for_element_to_disappear {
    my ($self, $locator, $timeout) = @_;
    $timeout ||= $self->default_timeout;

    my $element;
    my $expiry = time + $timeout / 1000;

    while ($element = $self->is_element_present($locator)) {
        Gtk3->main_iteration while Gtk3->events_pending;

        return 0 if time > $expiry;
        usleep 10000;
    }

    return 1;
}

=head3 wait_for_alert($text, $timeout)

Wait for an alert with the given text to happen.
If $text is undef, it waits for any alert. Since alerts do not get automatically cleared, this has to be done manually before causing the action that is supposed to throw a new alert:

    $webkit->alerts([]);
    $webkit->click('...');
    $webkit->wait_for_alert;

=cut

sub wait_for_alert {
    my ($self, $text, $timeout) = @_;
    $timeout ||= $self->default_timeout;

    my $expiry = time + $timeout / 1000;

    until (defined $text ? (@{ $self->alerts } and $self->alerts->[-1] eq $text) : @{ $self->alerts }) {
        Gtk3->main_iteration while Gtk3->events_pending;

        return 0 if time > $expiry;
        usleep 10000;
    }

    return 1;
}

=head3 native_drag_and_drop_to_object($source, $target)

Drag&drop that works with native HTML5 D&D events.

=cut

sub native_drag_and_drop_to_object {
    my ($self, $source, $target) = @_;

    $source = $self->resolve_locator($source);
    my ($source_x, $source_y) = $self->get_center_screen_position($source);

    $target = $self->resolve_locator($target);
    my ($target_x, $target_y) = $self->get_center_screen_position($target);

    my $display = X11::Xlib->new;
    $display->XTestFakeMotionEvent(0, $source_x, $source_y, 5);
    $display->XFlush;
    $self->pause(50); # Time for DnD to kick in
    $display->XTestFakeButtonEvent(1, 1, 0);
    $display->XFlush;
    $self->pause(50);
    $display->XTestFakeMotionEvent(0, $source_x, $source_y - 1, 5);
    $display->XFlush;
    $self->pause(50);
    $display->XTestFakeMotionEvent(0, $target_x, $target_y + 1, 5);
    $display->XFlush;
    $self->pause(50);
    $display->XTestFakeMotionEvent(0, $target_x, $target_y, 5);
    $display->XFlush;
    $self->pause(50);
    $display->XTestFakeButtonEvent(1, 0, 5);
    $display->XFlush;
    # Mouse cursor jumps to 0,0 for no apparrent reason. Move it back to the target
    $self->pause(50);
    $display->XTestFakeMotionEvent(0, $target_x, $target_y + 1, 5);
    $display->XFlush;
    $self->pause(50);
    $display->XTestFakeMotionEvent(0, $target_x, $target_y, 5);
    $display->XFlush;
    $self->pause(50);
}

sub get_screen_position {
    my ($self, $element) = @_;

    my $x = 0;
    my $y = 0;

    do {
        $x += $element->get_offset_left;
        $y += $element->get_offset_top;
    } while ($element = $element->get_offset_parent);

    return ($x, $y);
}

sub get_center_screen_position {
    my ($self, $element) = @_;

    my ($x, $y) = $self->get_screen_position($element);
    $x += $element->get_offset_width / 2;
    $y += $element->get_offset_height / 2;

    return ($x, $y);
}

1;

=head1 SEE ALSO

See L<WWW::Selenium> for API documentation.
See L<Test::WWW::WebKit> for a replacement for L<Test::WWW::Selenium>.
See L<Test::WWW::WebKit::Catalyst> for a replacement for L<Test::WWW::Selenium::Catalyst>.

=head1 AUTHOR

Stefan Seifert, E<lt>nine@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Stefan Seifert

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
