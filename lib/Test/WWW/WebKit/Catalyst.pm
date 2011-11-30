package Test::WWW::WebKit::Catalyst;

use 5.10.0;
use Moose;

extends 'Test::WWW::WebKit';

has app => (
    is       => 'ro',
    isa      => 'ClassName',
    required => 1,
);

has server_pid => (
    is  => 'rw',
    isa => 'Int',
);

has server => (
    is => 'rw',
);

sub DESTROY {
    my ($self) = @_;
    return unless $self->server_pid;

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

before init => sub {
    my ($self) = @_;

    $ENV{CATALYST_PORT} = $self->start_catalyst_server;
};

1;
