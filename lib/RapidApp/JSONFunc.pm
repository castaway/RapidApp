package RapidApp::JSONFunc;
#
# -------------------------------------------------------------- #
#


use strict;
use warnings;
use Moose;


use JSON::PP;

our $VERSION = '0.1';


BEGIN {

	# We need to do this so that JSON won't quote the output of our
	# TO_JSON method and will allow us to return invalid JSON...
	# In this case, we're actually using the JSON lib to generate
	# JavaScript (with functions), not JSON

	#############################################
	#############################################
	######     OVERRIDE JSON::PP CLASS     ######
	use Class::MOP::Class;
	my $json_meta = Class::MOP::Class->initialize('JSON::PP');
	$json_meta->add_around_method_modifier(object_to_json => sub {
		my $orig = shift;
		my ($self, $obj) = @_;
		
		my $type = ref($obj);
		
		return $orig->(@_) unless (
			$type and
			$type eq __PACKAGE__ and
			$obj->can('TO_JSON')
		);
		
		return $obj->TO_JSON;

	}) unless $json_meta->get_method('object_to_json')->isa('Class::MOP::Method::Wrapped');
	######     OVERRIDE JSON::PP CLASS     ######
	#############################################
	#############################################
}


has 'function'		=> ( is => 'ro', required => 1, isa => 'Str' );
has 'config'		=> ( is => 'ro', required => 1 );

has 'json' => ( is => 'ro', lazy_build => 1 );
sub _build_json {
	my $self = shift;
	return JSON::PP->new->allow_blessed->convert_blessed;
}

sub TO_JSON {
	my $self = shift;
	return $self->function . '(' . $self->json->encode($self->config) . ')';
}




#### --------------------- ####




no Moose;
__PACKAGE__->meta->make_immutable;
1;
