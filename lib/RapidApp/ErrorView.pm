package RapidApp::Controller::ExceptionInspector;

use Moose;
extends 'RapidApp::AppStoreForm2';

use RapidApp::Include qw(perlutil sugar);

# make sure the as_html method gets loaded into StackTrace, which might get deserialized
use Devel::StackTrace;
use Devel::StackTrace::WithLexicals;
use Devel::StackTrace::AsHTML;

has 'exceptionStore' => ( is => 'rw' ); # either a store object, or a Model name

#merge_attr_defaults(
#	actions => {
#		view => 'view',
#		justdie => 'justdie',
#		diefancy => 'diefancy',
#		usererror => 'usererror',
#	},
#);

sub BUILD {
	my $self= shift;
	
	# Register ourselves with RapidApp if no other has already been registered
	# This affects any hyperlinks to exception reports generated by RapidApp modules.
	defined $self->app->rapidApp->errorViewPath
		or $self->app->rapidApp->errorViewPath($self->base_url);
	
	$self->apply_actions(
		view => 'view',
		justdie => 'justdie',
		diefancy => 'diefancy',
		usererror => 'usererror',
	);
}

sub viewport {
	my $self= shift;
	
	# Generating an exception while trying to view exceptions wouldn't be too useful
	#   so we trap and display exceptions specially in this module.
	try {
		my $id= $self->c->req->params->{id};
		defined $id or die "No ID specified";
		
		my $store= $self->exceptionStore;
		defined $store or die "No ExceptionStore configured";
		ref $store or $store= $c->model($store);
		
		my $err= $store->loadException($id);
		$self->c->stash->{ex}= $err;
	}
	catch {
		use Data::Dumper;
		$self->c->log->debug(Dumper(keys %$_));
		$self->c->stash->{ex}= { id => $id, error => $_ };
	};
	$self->c->stash->{current_view}= 'RapidApp::TT';
	$self->c->stash->{template}= 'templates/rapidapp/exception.tt';
}

sub justdie {
	die "Deliberately generating an exception";
}

sub diefancy {
	die RapidApp::Error->new("Generating an exception using the RapidApp::Error class");
}

sub usererror {
	die usererr "PEBKAC";
}

1;
