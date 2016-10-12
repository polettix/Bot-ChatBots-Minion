package Bot::ChatBots::Minion;
use strict;
use Ouch;
{ our $VERSION = '0.001004'; }

use Mojo::Base 'Mojolicious::Plugin';
use Log::Any ();
use Bot::ChatBots::Utils qw< pipeline resolve_module >;

has _minion  => sub { ouch 500, 'no minion set' };
has name     => sub { shift->typename };
has prefix   => 'Bot::ChatBots';
has typename => sub { return ref($_[0]) || $_[0] };

sub dequeuer {
   my $self = shift;
   my $args = (@_ && ref($_[0])) ? $_[0] : {@_};

   my $name = $args->{name} // $self->name // '<unknown dequeuer>';

   my $ds = $args->{downstream} // $args->{processor}
     or ouch 500, 'no processor provided for dequeuer';
   $ds = pipeline((ref($ds) eq 'ARRAY') ? @$ds : $ds);

   return sub {
      my ($job, $record) = @_;
      $self->logger->info("dequeuing for $name");
      my @retval = $ds->($record);
      $job->finish('All went well... hopefully');
      return @retval;
   };
}

sub enqueue {
   my ($self, $record, $name) = @_;
   return $self->enqueuer($name)->($record);
} ## end sub enqueue

sub enqueuer {
   my ($self, $name)= @_;

   $name //= $self->name
     or ouch 500, 'no task name provided for enqueuer';

   state $cache = {};
   return $cache->{$name} //= sub {
      my $record = shift;
      $self->logger->info("enqueueing for $name");
      $self->minion->enqueue($name, [$record]);
      return $record;
   };
}

sub install_dequeuer {
   my $self = shift;
   my $args = (@_ && ref($_[0])) ? $_[0] : {@_};
   my $name = $args->{name} // $self->name
     or ouch 500, 'no task name available for installing dequeuer';
   $self->minion->add_task($name => $self->dequeuer($args));
   return $self;
}

sub logger { return Log::Any->get_logger };

sub minion {
   my $self = shift;
   if (@_) {
      my $minion = shift;
      if (ref($minion) eq 'ARRAY') {
         require Minion;
         $minion = Minion->new(@$minion);
      }
      return $self->_minion($minion);
   }
   return $self->_minion;
}

sub register {
   my ($self, $app, $conf) = @_;

   my $minion;
   if (my $pconf = $conf->{Minion}) {
      $app->plugin(Minion => @{$conf->{Minion}});
      $minion = $app->minion;
   }
   else {
      $minion = $conf->{minion} // eval { $app->minion };
   }
   $self->minion($minion) if defined $minion;

   $self->name($conf->{name}) if exists $conf->{name};
   $self->prefix($conf->{prefix}) if exists $conf->{prefix};
   $self->typename($conf->{typename}) if exists $conf->{typename};

   $app->helper('chatbots.minion' => sub { $self });

   return $self;
} ## end sub register

sub wrapper {
   my $self = shift;
   my $args = (@_ && ref($_[0])) ? $_[0] : {@_};
   $self->install_dequeuer($args);
   return $self->enqueuer($args->{name} // $self->name);
}

42;
