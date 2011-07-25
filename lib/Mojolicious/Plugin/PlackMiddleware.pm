package Mojolicious::Plugin::PlackMiddleware;
use strict;
use warnings;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Server::PSGI;
use Plack::Util;
use Mojo::Message::Request;
our $VERSION = '0.16';

    ### ---
    ### register
    ### ---
    sub register {
        my ($self, $app, $mws) = @_;
        
        my $on_process_org = $app->on_process;
        
        my $plack_app = sub {
            my $env = shift;
            my $c = $env->{'MOJO.CONTROLLER'};
            $c->req(Mojo::Message::Request->new->parse($env));
            $on_process_org->($c->app, $c);
            return mojo_res_to_psgi_res($c->res);
        };
        
        my @mws = reverse @$mws;
        while (scalar @mws) {
            my $args = (ref $mws[0] eq 'HASH') ? shift @mws : undef;
            my $cond = (ref $mws[0] eq 'CODE') ? shift @mws : undef;
            my $e = shift @mws;
            $e = _load_class($e, 'Plack::Middleware');
            $plack_app = Mojolicious::Plugin::PlackMiddleware::_Cond->wrap(
                $plack_app,
                condition => $cond,
                builder => sub {$e->wrap($_[0], %$args)},
            );
        }
        
        $app->on_process(sub {
            
            my ($app, $c) = @_;
            my $plack_env = mojo_req_to_psgi_env($c->req);
            $plack_env->{'psgi.errors'} =
                            Mojolicious::Plugin::PlackMiddleware::_EH->new($c);
            $plack_env->{'MOJO.CONTROLLER'} = $c;
            my $plack_res = $plack_app->($plack_env);
            my $mojo_res = psgi_res_to_mojo_res($plack_res);
            $c->tx->res($mojo_res);
            
            if (! $c->stash('mojo.routed')) {
                $c->rendered;
            }
        });
    }
    
    ### ---
    ### convert mojo tx to psgi env
    ### ---
    sub mojo_req_to_psgi_env {
        
        my $mojo_req = shift;
        my $url = $mojo_req->url;
        my $base = $url->base;
        my $host = $base->host;
        return {
            %ENV,
            'SERVER_PROTOCOL'   => 'HTTP/'. $mojo_req->version,
            'SERVER_NAME'       => $host,
            'SERVER_PORT'       => $base->port,
            'HTTP_HOST'         => $host. ':' .$base->port,
            'HTTP_AUTHORIZATION' => sub {
                    my $a = $mojo_req->headers->header('authorization');
                    return $a || '';
                }->(),
            'REQUEST_METHOD'    => $mojo_req->method,
            'SCRIPT_NAME'       => '',
            'PATH_INFO'         => $url->path->to_string,
            'REQUEST_URI'       => $url->to_string,
            'QUERY_STRING'      => $url->query->to_string,
            'psgi.url_scheme'   => $base->scheme,
            'psgi.multithread'  => Plack::Util::FALSE,
            'psgi.version'      => [1,1],
            'psgi.errors'       => *STDERR,
            'psgi.multithread'  => Plack::Util::FALSE,
            'psgi.multiprocess' => Plack::Util::TRUE,
            'psgi.run_once'     => Plack::Util::FALSE,
            'psgi.streaming'    => Plack::Util::TRUE,
            'psgi.nonblocking'  => Plack::Util::FALSE,
        };
    }
    
    ### ---
    ### convert psgi res to mojo res
    ### ---
    sub psgi_res_to_mojo_res {
        my $psgi_res = shift;
        my $mojo_res = Mojo::Message::Response->new;
        $mojo_res->code($psgi_res->[0]);
        my $headers = $mojo_res->headers;
        while (scalar @{$psgi_res->[1]}) {
            $headers->header(shift @{$psgi_res->[1]} => shift @{$psgi_res->[1]});
        }
        
        $headers->remove('Content-Length'); # should be set by mojolicious later
        
        my $asset = $mojo_res->content->asset;
        Plack::Util::foreach($psgi_res->[2], sub {$asset->add_chunk($_[0])});
        return $mojo_res;
    }
    
    ### ---
    ### convert mojo res to psgi res
    ### ---
    sub mojo_res_to_psgi_res {
        my $mojo_res = shift;
        my $status = $mojo_res->code;
        my $headers = $mojo_res->content->headers;
        my @headers;
        for my $name (@{$headers->names}) {
            for my $values ($headers->header($name)) {
                push @headers, $name => $_ for @$values;
            }
        }
        my @body;
        my $offset = 0;
        while (my $chunk = $mojo_res->get_body_chunk($offset)) {
            push(@body, $chunk);
            $offset += length $chunk;
        }
        return [$status, \@headers, \@body];
    }
    
    ### ---
    ### load mw class
    ### ---
    sub _load_class {
        my($class, $prefix) = @_;
        
        if ($prefix) {
            unless ($class =~ s/^\+// || $class =~ /^$prefix/) {
                $class = "$prefix\::$class";
            }
        }
        if ($class->can('call')) {
            return $class;
        }
        my $file = $class;
        $file =~ s!::!/!g;
        require "$file.pm"; ## no critic
    
        return $class;
    }


### ---
### Error Handler
### ---
package Mojolicious::Plugin::PlackMiddleware::_EH;
use Mojo::Base -base;
    
    __PACKAGE__->attr('controller');
    
    sub new {
        my ($class, $c) = @_;
        my $self = $class->SUPER::new;
        $self->controller($c);
    }
    
    sub print {
        shift->controller->app->log->debug(shift);
    }

### ---
### Port of Plack::Middleware::Conditional with mojolicious controller
### ---
package Mojolicious::Plugin::PlackMiddleware::_Cond;
use strict;
use parent qw(Plack::Middleware::Conditional);
    
    sub call {
        my($self, $env) = @_;
        my $cond = $self->condition;
        if (! $cond || $cond->($env->{'MOJO.CONTROLLER'})) {
            return $self->middleware->($env);
        } else {
            return $self->app->($env);
        }
    }

1;

__END__

=head1 NAME

Mojolicious::Plugin::PlackMiddleware - Plack::Middleware inside Mojolicious

=head1 SYNOPSIS

    # Mojolicious
    
    sub startup {
        
        my $self = shift;
        
        $self->plugin(plack_middleware => [
            'MyMiddleware1', 
            'MyMiddleware2', {arg1 => 'some_vale'},
            'MyMiddleware3', sub {$condition}, 
            'MyMiddleware4', sub {$condition}, {arg1 => 'some_vale'}
        ]);
    }
    
    # Mojolicious::Lite
    
    plugin plack_middleware => [
        'MyMiddleware1', 
        'MyMiddleware2', {arg1 => 'some_vale'},
        'MyMiddleware3', sub {$condition}, 
        'MyMiddleware4', sub {$condition}, {arg1 => 'some_vale'}
    ];
    
    package Plack::Middleware::MyMiddleware1;
    use strict;
    use warnings;
    use base qw( Plack::Middleware );
    
    sub call {
        my($self, $env) = @_;
        # pre-processing $env
        my $res = $self->app->($env);
        # post-processing $res
        return $res;
    }
  
=head1 DESCRIPTION

Mojolicious::Plugin::PlackMiddleware allows you to enable Plack::Middleware
inside Mojolicious by wrapping on_proccess so that the portability of your app
covers pre/post process too.

It also aimed at those who used to Mojolicious bundle servers.
Note that if you can run your application on a plack server, there is proper
ways to use middlewares. See L<http://blog.kraih.com/mojolicious-and-plack>.

=head2 OPTIONS

This plugin takes an argument in Array reference which contains some
middlewares. Each middleware can be followed by callback function for
conditional activation, and attributes for middleware.

    my $condition = sub {
        my $c = shift; # Mojolicious controller
        if (...) {
            return 1; # causes the middleware hooked
        }
    };
    plugin plack_middleware => [
        Plack::Middleware::MyMiddleware, $condition, {arg1 => 'some_vale'},
    ];

=head1 METHODS

=head2 register

$plugin->register;

Register plugin hooks in L<Mojolicious> application.

=head2 mojo_req_to_psgi_env

This is a utility method. This is for internal use.

    my $plack_env = mojo_req_to_psgi_env($mojo_req)

=head2 psgi_res_to_mojo_res

This is a utility method. This is for internal use.

    my $mojo_res = psgi_res_to_mojo_res($psgi_res)

=head2 mojo_res_to_psgi_res

This is a utility method. This is for internal use.

    my $psgi_res = mojo_res_to_psgi_res($mojo_res)

=head1 Example1

    $self->plugin(plack_middleware => [
        'Auth::Basic' => sub {shift->req->url =~ qr{/path1/}}, {
            authenticator => sub {
                my ($user, $pass) = @_;
                return $username eq 'user1' && $password eq 'pass';
            }
        },
        'Auth::Basic' => sub {shift->req->url =~ qr{/path2/}}, {
            authenticator => sub {
                my ($user, $pass) = @_;
                return $username eq 'user2' && $password eq 'pass2';
            }
        },
    ]);

=head1 AUTHOR

Sugama Keita, E<lt>sugama@jamadam.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Sugama Keita.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
