package WashU::Billing::Model::AdapterBillingUnit;
#by "billing unit" i really mean one row of their spreadsheet
use Moose;
use DataAdapter::Result;
use Moose::Util::TypeConstraints;
use Date::Manip;
use WashU::Billing::MooseTypeLibrary qw(mmddyy DollarInt INVOICE_DESTINATION_TYPE );
use warnings FATAL => qw(all);
extends 'DataAdapter::Result';

has 'date'                 => ( isa => mmddyy, is => 'rw', required => 1, coerce => 1 );
has 'activity'             => ( isa => 'Str', is => 'rw', required => 1 );
has 'project_name'         => ( isa => 'Str', is => 'rw', required => 1 );
has 'sample_description'   => ( isa => 'Str', is => 'rw', required => 1 );
has 'totalqty'             => ( isa => 'Str', is => 'rw', required => 1 );
has 'rate'                 => ( isa => DollarInt, is => 'rw', required => 1, coerce => 1);
has 'billabletotal'        => ( isa => DollarInt, is => 'rw', required => 1, coerce => 1, init_arg => 'billable_total');
has 'per'                  => ( isa => 'Str', is => 'rw', required => 1 );
has 'washu_deptnbr'        => ( isa => 'Int', is => 'rw', required => 1 );
has 'primary_collaborator' => ( isa => 'Str', is => 'rw', required => 1 );
has 'accounts_payable_contact' => ( isa => 'Str', is => 'rw' );
has 'ponbr' => ( isa => 'Str', is => 'rw', default => sub {'none'} );
has 'invoice_destination'=> ( is => 'rw', isa => INVOICE_DESTINATION_TYPE, lazy_build => 1 );

has 'item_description' => (
    is => 'rw',
    isa => 'Str',
    lazy_build => 1
);

sub _build_invoice_destination {
     return (sprintf("%d", shift->washu_deptnbr) == 0) ? 'external' : 'internal';
}

sub _build_item_description {
     my $self = shift;

     return  $self->totalqty . ' (' . $self->per . ') At $'. &commify($self->rate);
}

sub commify {
    my ($val)= @_;
    ( my $num = $val ) =~ s/\G(\d{1,3})(?=(?:\d\d\d)+(?:\.|$))/$1,/g;
    return $num;
}

sub invoice_group_by_string {
    my $self = shift;
    return $self->project_name . "::" . $self->washu_deptnbr . "::" . $self->primary_collaborator;
}

no Moose;
1;

