package WashU::Billing::Model::InterDepartmentBulkInvoice;

use Moose; 
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use WashU::Billing::Model::CobolRecord;
use WashU::Billing::Model::InvoiceUnit::ProjectDepartmentID;
use Try::Tiny;
use List::AllUtils qw/uniq/;
use WashU::Billing::MooseTypeLibrary qw(ValidFile);

with 'WashU::Billing::Model::Role::InvoiceParams';

has 'batch_header' => (
    is => 'rw',
    isa => 'WashU::Billing::Model::CobolRecord',
    lazy_build => 1
);

has 'batch_trailer' => (
    is => 'rw',
    isa => 'WashU::Billing::Model::CobolRecord',
    lazy_build => 1
);

has 'project_department_ids' => (
    is => 'rw',
    isa => 'ArrayRef[WashU::Billing::Model::InvoiceUnit::ProjectDepartmentID]',
    required => 1
);

has "+invoice_destination" => (default => 'internal');

sub row_data { [map{@{$_->row_data}} @{shift->project_department_ids}] }

sub _build_batch_header {
    my $self = shift;

    my $batch_header =  WashU::Billing::Model::CobolRecord->new(record_code => '000' );
    $batch_header->set_field_data(
        department_number =>  $self->invoice_department_number,
        department_name =>  $self->invoice_department_name,
        contact_person  =>  $self->invoice_contact_person,
        contact_phone_number => $self->invoice_contact_phone,
        date_batch_sent => $self->invoice_date,
        time_batch_sent => $self->invoice_time
    );
    return $batch_header;
}

sub _build_batch_trailer{
    my $self = shift;
    my $header =  WashU::Billing::Model::CobolRecord->new(record_code => '999' );
    $header->set_field_data(
        department_number =>  $self->invoice_department_number,
        date_batch_sent => $self->invoice_date,
        time_batch_sent => $self->invoice_time,
        document_count=> scalar(@{$self->project_department_ids})
    );

    return $header;
}

sub _build_billing_records {
    my $self = shift;
    my $h = $self->batch_header;
    my @m = map{@{$_->billing_records}} @{ $self->project_department_ids};
    my $t = $self->batch_trailer ;
    return [$h, @m, $t];
}

__PACKAGE__->meta->make_immutable;
1;
