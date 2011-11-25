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
use Test::More;

use constant DOM_TYPE_ELEMENT => 1;
use constant ORDERED_NODE_SNAPSHOT_TYPE => 7;

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

sub resolve_locator {
    my ($self, $locator, $document, $context) = @_;

    $document ||= $self->view->get_dom_document;
    $context ||= $document;

    if (my ($xpath) = $locator =~ /^xpath=(.*)/) {
        my $resolver = $document->create_ns_resolver($context);
        my $xpath_results = $document->evaluate($xpath, $context, $resolver, ORDERED_NODE_SNAPSHOT_TYPE, undef);
        my $length = $xpath_results->get_snapshot_length;
        die "$xpath gave $length results" if $length != 1;
        return $xpath_results->snapshot_item(0);
    }
    elsif (my ($label) = $locator =~ /^label=(.*)/) {
        return $self->resolve_locator(qq{xpath=.//*[text()="$label"]}, $document, $context);
    }
    elsif (my ($id) = $locator =~ /^id=(.*)/) {
        return $document->get_element_by_id($id);
    }

    warn "unknown locator $locator";
    die "unknown locator $locator";
}

sub select_ok {
    my ($self, $select, $option) = @_;

    my $document = $self->view->get_dom_document;
    $select = $self->resolve_locator($select, $document);
    $option = $self->resolve_locator($option, $document, $select);

    my $options = $select->get_property('options');
    foreach my $i (0 .. $options->get_length) {
        my $current = $options->item($i);

        if ($current->is_same_node($option)) {
            $select->set_selected_index($i);

            my $changed = $document->create_event('Event');
            $changed->init_event('change', TRUE, TRUE);
            $select->dispatch_event($changed);

            Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
            return;
        }
    }
}

sub click_ok {
    my ($self, $locator) = @_;

    my $document = $self->view->get_dom_document;
    my $target = $self->resolve_locator($locator, $document);

    my $click = $document->create_event('MouseEvent');
    $click->init_event('click', TRUE, TRUE, $document->get_property('default_view'), 1, 0, 0, 0, 0, FALSE, FALSE, FALSE, FALSE, 0, undef);
    $target->dispatch_event($click);
}

sub wait_for_page_to_load_ok {
    my ($self, $timeout) = @_;
    Gtk3->main_iteration while Gtk3->events_pending or $self->view->get_load_status ne 'finished';
}

sub wait_for_element_present_ok {
    my ($self, $locator) = @_;

    my $document = $self->view->get_dom_document;

    Gtk3->main_iteration while Gtk3->events_pending or not eval { $self->resolve_locator($locator, $document) };
}

sub is_element_present_ok {
    my ($self, $locator) = @_;

    ok(eval { $self->resolve_locator($locator) });
}

sub get_text {
    my ($self, $locator) = @_;

    return $self->resolve_locator($locator)->get_text_content;
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
