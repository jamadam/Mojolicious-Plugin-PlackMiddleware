package MojoliciousTest::Foo;
use Mojo::Base 'Mojolicious::Controller';

sub authenticated {
  my $self = shift;
  $self->render(text => $self->stash('action'));
}

sub config {
  my $self = shift;
  $self->render_text($self->stash('config')->{test});
}

sub fun { shift->render(text => 'Have fun!') }

sub index {
  my $self = shift;
  $self->layout('default');
  $self->stash(handler => 'xpl', msg => 'Hello World!');
}

sub plugin_camel_case {
  my $self = shift;
  $self->render_text($self->some_plugin);
}

sub plugin_upper_case {
  my $self = shift;
  $self->render_text($self->upper_case_test_plugin);
}

sub session_domain {
  my $self = shift;
  $self->session(user => 'Bender');
  $self->render_text('Bender rockzzz!');
}

sub something {
  my $self = shift;
  $self->res->headers->header('X-Bender' => 'Bite my shiny metal ass!');
  $self->render_text($self->url_for('something', something => '42'));
}

sub stage1 {
  my $self = shift;

  # Authenticated
  return 1 if $self->req->headers->header('X-Pass');

  # Fail
  $self->render_text('Go away!');
  return undef;
}

sub stage2 {
  my $self = shift;
  $self->render_text($self->some_plugin);
}

sub syntaxerror { shift->render('syntaxerror', format => 'html') }

sub templateless { shift->render(handler => 'test') }

sub test {
  my $self = shift;
  $self->res->headers->header('X-Bender' => 'Bite my shiny metal ass!');
  $self->render_text($self->url_for(controller => 'bar'));
}

sub url_for_missing {
  my $self = shift;
  $self->render_text($self->url_for('does_not_exist', something => '42'));
}

sub willdie { die 'for some reason' }

sub withblock { shift->render(template => 'withblock') }

sub withlayout { shift->stash(template => 'withlayout') }

1;
__DATA__

@@ just/some/template.html.epl
Development template with high precedence.

@@ some/static/file.txt
Development static file with high precedence.
