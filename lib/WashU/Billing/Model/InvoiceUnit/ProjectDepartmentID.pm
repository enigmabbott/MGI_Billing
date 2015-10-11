package WashU::Billing::Model::InvoiceUnit::ProjectDepartmentID;

use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use List::AllUtils qw(sum uniq);
use WashU::Billing::MooseTypeLibrary qw(ArrayRefMax999);
use WashU::Billing::Model::CobolRecord;

extends 'WashU::Billing::Model::InvoiceUnit';
with 'WashU::Billing::Model::Role::InvoiceParams';

#old sub credit_account_number {'0200001235338100  '}
#use constant CREDIT_ACCOUNT_NUMBER => '1235338100   93400';
#use constant CREDIT_ACCOUNT_NUMBER => '1235338100   91000';
use constant CREDIT_ACCOUNT_NUMBER => '1235338100   93300';

has '+row_data' => (
    isa => ArrayRefMax999, 
);

has invoice_header1 => (
   is => 'rw',
   isa => 'WashU::Billing::Model::CobolRecord',
   lazy_build => 1
);

has invoice_header2 => (
   is => 'rw',
   isa => 'WashU::Billing::Model::CobolRecord',
   lazy_build => 1
);

has invoice_credit_accounts => (
   is => 'rw',
   isa => 'WashU::Billing::Model::CobolRecord',
   lazy_build => 1,
);

has invoice_debit_accounts => (
   is => 'rw',
   isa => 'WashU::Billing::Model::CobolRecord',
   lazy_build => 1,
);

has invoice_receipt_record => (
   is => 'rw',
   isa => 'WashU::Billing::Model::CobolRecord',
   lazy_build => 1,
);

has invoice_item_detail_records=> (
   is => 'rw',
   isa => 'ArrayRef[WashU::Billing::Model::CobolRecord]',
   lazy_build => 1,
);

sub _build_invoice_item_detail_records {
    my $self = shift;
    my $record_code = '040';
    
    my @records;

    my $sequence_number = 0;
#header
    my $project_br=WashU::Billing::Model::CobolRecord->new(record_code => $record_code);
    my $max= 48;
    my $desc = "Project: " . $self->project_name;
    $desc = substr($desc,0,48) if length($desc) > $max;

        $project_br->set_field_data(
            sequence_number => ++$sequence_number,
            item_description =>  $desc
        ) or die;
    push @records, $project_br; 

    my $invoice_br =  WashU::Billing::Model::CobolRecord->new(record_code => $record_code);
    $invoice_br->set_field_data(
        sequence_number => ++$sequence_number,
        item_date => $self->invoice_date,
        item_description => 'Invoice ' . $self->invoice_sequence . ' will auto-pay in 30 days!',
    );
    push @records, $invoice_br; 

    my $i=0;
    for my $row_obj ( @{$self->row_data}){
        
        my $item_amount = $row_obj->billabletotal;

        my $br = WashU::Billing::Model::CobolRecord->new(record_code => $record_code);
        $br->set_field_data(
                sequence_number => ++$sequence_number,
                item_number => ++$i,
                item_quantity => $row_obj->totalqty_formatted, 
                item_date => $self->invoice_date,
                item_description =>  $row_obj->sample_description_formatted,
                item_amount => abs($row_obj->billabletotal),
                item_amount_sign => ($row_obj->billabletotal< 0 ? "-":'')
            );
        push @records, $br; 

        $br = WashU::Billing::Model::CobolRecord->new(record_code => $record_code);
        $br->set_field_data(
            sequence_number => ++$sequence_number,
            item_description => $row_obj->activity_formatted
        );
        push @records, $br; 

        $br = WashU::Billing::Model::CobolRecord->new(record_code => $record_code);
        $br->set_field_data(
            sequence_number => $sequence_number, #purposely not iterating
            item_description =>  $row_obj->item_description
        );
        push @records, $br; 
    }

    return \@records;
}

sub _build_invoice_header1 {
    my $self = shift;

#010 ID 003533 Brockhouse, Rose         122110 0085 286-1801000000000000N11
    my $br=  WashU::Billing::Model::CobolRecord->new(record_code => '010');
    $br->set_field_data(
        document_type => 'ID',
        billing_dept => $self->invoice_department_number,
        contact_name  =>  $self->invoice_contact_person,
        invoice_date  => $self->invoice_date,
        contact_box_number => $self->invoice_contact_box_number,
        contact_phone_number => $self->invoice_contact_phone,
        documentation_with => 'N',
        fiscal_year => $self->invoice_year
    );
    return $br;
}

sub _build_invoice_header2 {
    my $self = shift;

#011003533Genetics GC              003533Genetics GC               0000420000
    my $invoice_amount = $self->invoice_amount;

    my $br = WashU::Billing::Model::CobolRecord->new(record_code => '011');
    $br->set_field_data(
        send_to_dept =>$self->washu_department,
        vendor_dept => $self->invoice_department_number,
        vendor_dept_name => $self->invoice_department_name,
        invoice_amount => abs($invoice_amount),
        invoice_amount_sign => ($invoice_amount < 0 ? "-":'')
    );

    return $br;
}

sub _build_invoice_credit_accounts {
    my $self = shift;

#0200001235338100  93400  0000420000
    my $invoice_amount = $self->invoice_amount;

    my $br=  WashU::Billing::Model::CobolRecord->new(record_code => '020');
    $br->set_field_data(
        credit_account_number => $self->CREDIT_ACCOUNT_NUMBER,
        credit_amount => abs($invoice_amount),
        credit_amount_sign => ($invoice_amount < 0 ? "-":'')
    );

    return $br;
}

sub _build_invoice_debit_accounts {
    my $br = WashU::Billing::Model::CobolRecord->new(record_code => '030');
    $br->set_field_data;
    return $br;
}

sub _build_invoice_receipt_record {
    my $self = shift;
    my $br = WashU::Billing::Model::CobolRecord->new(record_code => '050');
    $br->set_field_data(received_by_name => $self->received_by_name );
    return $br;
}

sub received_by_name {
    return join("; ", sort{$a cmp $b} uniq  map { $_->primary_collaborator } @{shift->row_data });
}

sub _build_billing_records {
    my $self = shift;
    return [ $self->invoice_header1,
             $self->invoice_header2, 
             $self->invoice_credit_accounts,
             $self->invoice_debit_accounts,
             @{$self->invoice_item_detail_records},
             $self->invoice_receipt_record,
           ];
}

sub primary_collaborator {
    my $self = shift;
    my @names = uniq map{$_->primary_collaborator} @{$self->row_data} or return '';
    return join(",", @names);
}

__PACKAGE__->meta->make_immutable;
1;
