package RapidApp::Role::DataStore2;
use Moose::Role;
use Moose::Util::TypeConstraints;

use RapidApp::Include qw(sugar perlutil);
use Clone qw(clone);

use RapidApp::DataStore2;

subtype 'TableSpec', as 'Object', where { $_->isa('RapidApp::TableSpec') };

has 'TableSpec' => ( is => 'ro', isa => 'Maybe[TableSpec]', lazy_build => 1 );
sub _build_TableSpec { undef; }

has 'TableSpec_applied' => ( is => 'rw', isa => 'Bool', default => 0 );

has 'record_pk'			=> ( is => 'ro', default => 'id' );
has 'DataStore_class'	=> ( is => 'ro', default => 'RapidApp::DataStore2' );

has 'max_pagesize'		=> ( is => 'ro', isa => 'Maybe[Int]', default => undef );

has 'persist_all_immediately' => ( is => 'ro', isa => 'Bool', default => 0 );
has 'persist_immediately' => ( is => 'ro', isa => 'HashRef', default => sub{{
	create	=> \0,
	update	=> \0,
	destroy	=> \0
}});

has 'DataStore' => (
	is			=> 'rw',
	isa		=> 'RapidApp::DataStore2',
	handles => {
		JsonStore					=> 'JsonStore',
#		store_read					=> 'store_read',
#		store_read_raw				=> 'store_read_raw',
		columns						=> 'columns',
		column_order				=> 'column_order',
		include_columns			=> 'include_columns',
		exclude_columns			=> 'exclude_columns',
		include_columns_hash		=> 'include_columns_hash',
		exclude_columns_hash		=> 'exclude_columns_hash',
		apply_columns				=> 'apply_columns',
		column_list					=> 'column_list',
		apply_to_all_columns		=> 'apply_to_all_columns',
		applyIf_to_all_columns	=> 'applyIf_to_all_columns',
		apply_columns_list		=> 'apply_columns_list',
		set_sort						=> 'set_sort',
		batch_apply_opts			=> 'batch_apply_opts',
		set_columns_order			=> 'set_columns_order',
#		record_pk					=> 'record_pk',
		getStore						=> 'getStore',
		getStore_code				=> 'getStore_code',
		getStore_func				=> 'getStore_func',
		store_load_code			=> 'store_load_code',
		store_listeners			=> 'listeners',
		apply_store_listeners	=> 'apply_listeners',
		apply_store_config		=> 'apply_extconfig',
		valid_colname				=> 'valid_colname',
		apply_columns_ordered	=> 'apply_columns_ordered',
		batch_apply_opts_existing => 'batch_apply_opts_existing',
		delete_columns				=> 'delete_columns',
		has_column					=> 'has_column',
		get_column					=> 'get_column',
		deleted_column_names		=> 'deleted_column_names',
		column_name_list			=> 'column_name_list'
		
	}
);


has 'DataStore_build_params' => ( is => 'ro', default => undef, isa => 'Maybe[HashRef]' );

has 'defer_to_store_module' => ( is => 'ro', isa => 'Maybe[Object]', lazy => 1, default => undef ); 

around 'columns' => \&defer_store_around_modifier;
around 'column_order' => \&defer_store_around_modifier;
around 'has_column' => \&defer_store_around_modifier;
around 'get_column' => \&defer_store_around_modifier;

sub defer_store_around_modifier {
	my $orig = shift;
	my $self = shift;
	return $self->$orig(@_) unless (defined $self->defer_to_store_module);
	return $self->defer_to_store_module->$orig(@_);
}


# We are doing it this way so we can hook into this exact spot with method modifiers in other places:
sub BUILD {}
before 'BUILD' => sub { (shift)->DataStore2_BUILD };
sub DataStore2_BUILD {
	my $self = shift;
	
	my $store_params = { 
		record_pk 		=> $self->record_pk,
		max_pagesize	=> $self->max_pagesize
	};
	
	if ($self->can('create_records')) {
		$self->apply_flags( can_create => 1 ) unless ($self->flag_defined('can_create'));
		$store_params->{create_handler}	= RapidApp::Handler->new( scope => $self, method => 'create_records' ) if ($self->has_flag('can_create'));
	}
	
	if ($self->can('read_records')) {
		$self->apply_flags( can_read => 1 ) unless ($self->flag_defined('can_read'));
		$store_params->{read_handler}	= RapidApp::Handler->new( scope => $self, method => 'read_records' ) if ($self->has_flag('can_read'));
	}
	
	if ($self->can('update_records')) {
		$self->apply_flags( can_update => 1 ) unless ($self->flag_defined('can_update'));
		$store_params->{update_handler}	= RapidApp::Handler->new( scope => $self, method => 'update_records' ) if ($self->has_flag('can_update'));
	}
	
	if ($self->can('destroy_records')) {
		$self->apply_flags( can_destroy => 1 ) unless ($self->flag_defined('can_destroy'));
		$store_params->{destroy_handler}	= RapidApp::Handler->new( scope => $self, method => 'destroy_records' ) if ($self->has_flag('can_destroy'));
	}
	
	$store_params = {
		%$store_params,
		%{ $self->DataStore_build_params }
	} if (defined $self->DataStore_build_params);
	
	$self->apply_modules( store => {
		class		=> $self->DataStore_class,
		params	=> $store_params
	});
	$self->DataStore($self->Module('store',1));
	
	#init the store with all of our flags:
	$self->DataStore->apply_flags($self->all_flags);
	
	$self->add_ONREQUEST_calls('store_init_onrequest');
	$self->add_ONREQUEST_calls_late('apply_store_to_extconfig');
	
	# Init (but don't apply) TableSpec early
	$self->TableSpec;
}


after 'BUILD' => sub {
	my $self = shift;

	$self->apply_extconfig(
		persist_all_immediately => \scalar($self->persist_all_immediately),
		persist_immediately => $self->persist_immediately,
	);
	
	## Apply the TableSpec if its defined ##
	$self->apply_TableSpec_config;
	
	if(defined $self->Module('store',1)->create_handler) {
		$self->apply_actions( add_form => 'get_add_form' );
		$self->apply_extconfig( add_form_url => $self->suburl('add_form') );
	}
	
	$self->add_plugin( 'datastore-plus' );
};


sub apply_TableSpec_config {
	my $self = shift;
	$self->TableSpec or return;
	$self->TableSpec_applied and return;
	
	my $prop_names = [ @RapidApp::Column::attrs ];
	my $columns = $self->TableSpec->columns_properties_limited($prop_names);
	
	$self->apply_columns($columns);
	$self->set_columns_order(0,$self->TableSpec->column_names_ordered);
	
	$self->DataStore->add_onrequest_columns_mungers(
		$self->TableSpec->all_onrequest_columns_mungers
	) unless ($self->TableSpec->has_no_onrequest_columns_mungers);
	
	$self->TableSpec_applied(1);
}


sub defer_DataStore {
	my $self = shift;
	return $self->DataStore unless (defined $self->defer_to_store_module);
	return $self->defer_to_store_module->defer_DataStore if ($self->defer_to_store_module->can('defer_DataStore'));
	return $self->defer_to_store_module;
}

sub store_init_onrequest {
	my $self = shift;
	
	# Simulate direct ONREQUEST:
	$self->Module('store');
	
	$self->apply_extconfig( columns => $self->defer_DataStore->column_list );
	$self->apply_extconfig( sort => $self->defer_DataStore->get_extconfig_param('sort_spec') );
}


sub apply_store_to_extconfig {
	my $self = shift;
	
	if (defined $self->defer_to_store_module) {
		$self->apply_extconfig( store => $self->defer_DataStore->getStore_func );
	}
	else {
		$self->apply_extconfig( store => $self->Module('store')->JsonStore );
	}
}


sub get_add_form_items {
	my $self = shift;
	my @items = ();
	
	foreach my $colname (@{$self->column_order}) {
		my $Cnf = $self->columns->{$colname} or next;
		next unless (defined $Cnf->{editor} and $Cnf->{editor} ne '');
		
		#Skip columns with 'no_column' set to true except if 'allow_add' is true:
		next if (jstrue($Cnf->{no_column}) && ! jstrue($Cnf->{allow_add}));
		
		#Skip if allow_add is defined but set to false:
		next if (defined $Cnf->{allow_add} && ! jstrue($Cnf->{allow_add}));
		
		my $field = clone($Cnf->{editor});
		$field->{name} = $colname;
		$field->{allowBlank} = \1 unless (defined $field->{allowBlank});
		unless (jstrue $field->{allowBlank}) {
			$field->{labelStyle} = '' unless (defined $field->{labelStyle});
			$field->{labelStyle} .= 'font-weight:bold;';
		}
		$field->{header} = $Cnf->{header} if(defined $Cnf->{header});
		$field->{header} = $colname unless (defined $field->{header} and $field->{header} ne '');
		$field->{fieldLabel} = $field->{header};
		
		push @items, $field;
	}
	
	return @items;
}

sub get_add_form {
	my $self = shift;

	return {
		xtype => 'form',
		frame => \1,
		labelAlign => 'right',
		labelWidth => 70,
		plugins => ['dynamic-label-width'],
		bodyStyle => 'padding: 25px 10px 5px 5px;',
		defaults => {
			width => 250
		},
		autoScroll => \1,
		monitorValid => \1,
		buttonAlign => 'center',
		minButtonWidth => 100,
		
		# datastore-plus (client side) adds handlers based on the "name" properties 'save' and 'cancel' below
		buttons => [
			{
				name => 'save',
				text => 'Save',
				iconCls => 'icon-save',
				formBind => \1
			},
			{
				name => 'cancel',
				text => 'Cancel',
			}
		],
		items => [ $self->get_add_form_items ]
	};
}






#### --------------------- ####


no Moose;
#__PACKAGE__->meta->make_immutable;
1;