package Test::WWW::WebKit::Catalyst;

use 5.10.0;
use Moose;

use Gtk3 -init;
use Gtk3::WebKit;
use HTTP::Soup;
use Glib qw(TRUE FALSE);
use MIME::Base64;
use HTTP::Request::Common qw(POST);
use Time::HiRes qw(usleep);

has app => (
    is       => 'ro',
    isa      => 'ClassName',
    required => 1,
);

has view => (
    is      => 'ro',
    isa     => 'Gtk3::WebKit::WebView',
    default => sub {
        Gtk3::WebKit::WebView->new
    },
);

has window => (
    is      => 'ro',
    isa     => 'Gtk3::Window',
    default => sub {
        my ($self) = @_;
        my $sw = Gtk3::ScrolledWindow->new;
        $sw->add($self->view);

        my $win = Gtk3::Window->new;
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

has server_pid => (
    is  => 'rw',
    isa => 'Int',
);

has server => (
    is => 'rw',
);

has mech => (
    is  => 'ro',
    isa => 'WWW::Mechanize',
);

sub DESTROY {
    my ($self) = @_;
    kill 15, $self->server_pid;
    close $self->server;
}

sub start_catalyst_server {
    my ($self) = @_;

    my $pid;
    if (my $pid = open my $server, '-|') {
        $self->server_pid($pid);
        $self->server($server);
        my $port = <$server>;
        chomp $port;
        return $port;
    }
    else {
        local $SIG{TERM} = sub {
            exit 0;
        };

        my ($port, $catalyst);
        while (1) {
            $port = 1024 + int(rand(65535 - 1024));

            my $loader = Catalyst::EngineLoader->new(application_name => $self->app);
            eval {
                $catalyst = $loader->auto(port => $port, host => 'localhost');
            };
            warn $@ if $@;
            last unless $@;
        }
        say $port;
        $self->app->run($port, 'localhost', $catalyst);

        exit 1;
    }
}

sub init {
    my ($self) = @_;

    $ENV{CATALYST_PORT} = $self->start_catalyst_server;

    $self->view->signal_connect('script-alert' => sub {
        warn 'alert: ' . $_[2];
        push @{ $self->alerts }, $_[2];
    });
    $self->view->signal_connect('console-message' => sub {
        warn "console: $_[1] at line $_[2] in $_[3], user_data: $_[4]";
        push @{ $self->console_messages }, $_[1];
        return FALSE;
    });

    $self->window->show_all;
    Gtk3->main_iteration while Gtk3->events_pending;

    return $self;
}

sub open_ok {
    my ($self, $url) = @_;

    $self->view->open($url);

    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
}

sub eval_js {
    my ($self, $js) = @_;

    my $fn = "___run_js_$$";
    warn "function $fn() { $js }; alert($fn());";
    $self->view->execute_script("function $fn() { $js }; alert($fn());");
    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
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
    if ($locator =~ /^id=(.*)/) {
        return "document.getElementById('$1')";
    }
    die "unknown locator $locator";
}

sub select_ok {
    my ($self, $select, $option) = @_;

    $select = $self->code_for_selector($select);
    $option = $self->code_for_selector($option, 'select');

    return $self->eval_js("
        var select = $select;
        alert('select ' + select);
        var option = $option;
        alert('option ' + option);
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
        alert(target);
        evt.initMouseEvent('click', true, true, window, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
        return target.dispatchEvent(evt);
        JS
}

sub wait_for_page_to_load_ok {
    my ($self, $timeout) = @_;
    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
}

sub wait_for_element_present_ok {
    my ($self, $locator) = @_;
    my $element = $self->code_for_selector($locator);

    Gtk3->main_iteration while Gtk3->events_pending or $self->eval_js("return $element") eq 'null';
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
    usleep $time * 1000;
}

sub is_ordered_ok {
    warn "is_ordered_ok";
}

sub get_body_text {
    warn "get_body_text";
}

1;
