package Test::WWW::WebKit::Catalyst;

use Moose;

use Gtk2 -init;
use Gtk2::WebKit;
use Glib qw(TRUE FALSE);
use MIME::Base64;

has view => (
    is      => 'ro',
    isa     => 'Gtk2::WebKit::WebView',
    default => sub {
        Gtk2::WebKit::WebView->new
    },
);

has window => (
    is      => 'ro',
    isa     => 'Gtk2::Window',
    default => sub {
        my ($self) = @_;
        my $sw = Gtk2::ScrolledWindow->new;
        $sw->add($self->view);

        my $win = Gtk2::Window->new;
        $win->set_default_size(800, 600);
        $win->add($sw);
        return $win;
    }
);

has alerts => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has console_messages => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has mech => (
    is  => 'ro',
    isa => 'WWW::Mechanize',
);

sub init {
    my ($self) = @_;

    #$self->view->signal_connect('load-finished' => sub { Gtk2->main_quit });
    $self->view->signal_connect('script-alert' => sub {
        warn 'alert: ' . $_[2];
        push @{ $self->alerts }, $_[2];
    });
    $self->view->signal_connect('console-message' => sub {
        warn 'console: ' . $_[1];
        push @{ $self->console_messages }, $_[1];
    });
    $self->view->signal_connect('resource-request-starting' => sub {
        $self->load_uri(@_);
    });

    $self->window->show_all;
    Gtk2->main_iteration while Gtk2->events_pending;

    return $self;
}

sub open_ok {
    my ($self, $url) = @_;

    $self->view->open($url);

    Gtk2->main_iteration while Gtk2->events_pending and $self->view->get_load_status ne 'finished';
}

sub load_uri {
    my ($self, $view, $frame, $web_resource, $request, $response, $user_data) = @_;

    my $mech = $self->mech;

    my $uri = $request->get_uri;
    warn $request->get_property('message');
    $mech->request($uri);
    warn $uri;

    $request->set_uri('data:' . $mech->ct . ';base64,' . encode_base64($mech->content));

    return TRUE;
}

sub eval_js {
    my ($self, $js) = @_;

    my $fn = "___run_js_$$";
    #warn "function $fn() { $js }; alert($fn());";
    $self->view->execute_script("function $fn() { $js }; alert($fn());");
    Gtk2->main_iteration while Gtk2->events_pending;
    return pop @{ $self->alerts };
}

sub code_for_selector {
    my ($self, $locator, $context) = @_;

    $context ||= 'document';

    if ($locator =~ /^xpath=(.*)/) {
        return "document.evaluate('$1', $context, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue";
    }
    if ($locator =~ /^label=(.*)/) {
        return $self->code_for_selector(qq{xpath=//*[text()="$1"]}, $context);
    }
    die "unknown locator $locator";
}

sub select_ok {
    my ($self, $select, $option) = @_;

    $select = $self->code_for_selector($select);
    $option = $self->code_for_selector($option, 'select');

    return $self->eval_js("
        var select = $select;
        var option = $option;
        for (var i = 0; i < select.options.length; i++)
            if (select.options[i] == option)
                return select.selectedIndex = i;
    ");
}

sub click_ok {
    my ($self, $locator) = @_;

    my $target = $self->code_for_selector($locator);

    return $self->eval_js(<<"        JS");
        var evt = window.document.createEvent("MouseEvent");
        var target = $target;
        evt.initMouseEvent('click', true, true, window, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
        return target.dispatchEvent(evt);
        JS
}

sub wait_for_page_to_load_ok {
    #warn "wait_for_page_to_load_ok", @_;
}

sub wait_for_element_present_ok {
    #warn "wait_for_element_present_ok", @_;
}

sub is_element_present_ok {
    warn "is_element_present_ok", @_;
}

sub get_text {
    warn "get_text";
}

sub type_ok {
    warn "type_ok", @_;
}

sub key_press {
    warn "key_press", @_;
}

sub pause {
    my ($self, $time) = @_;
    sleep $time / 1000;
}

sub is_ordered_ok {
    warn "is_ordered_ok";
}

sub get_body_text {
    warn "get_body_text";
}

1;
