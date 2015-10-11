package WashU::Billing::Model::Role::InvoiceParams;

use Moose::Role;
use Moose::Util::TypeConstraints;
use WashU::Billing::Model::CobolRecord;
use DateTime;
use List::AllUtils qw/uniq/;
use WashU::Billing::MooseTypeLibrary qw(INVOICE_DESTINATION_TYPE );

has 'billing_records' => (
    is => 'rw',
    isa => 'ArrayRef[WashU::Billing::Model::CobolRecord]',
    lazy_build => 1
);

has 'invoice_date' => (
    is => 'rw',
    isa => 'Int',
    lazy_build => 1
);

has 'invoice_time' => (
    is => 'rw',
    isa => 'Int',
    lazy_build => 1
);

has 'invoice_contact_person' => (
    is => 'rw',
    isa => 'Str',
    default => 'Reily, Amy' 
);

has 'invoice_contact_phone' => (
    is => 'rw',
    isa => 'Str',
    default => '286-1801' 
);

has 'invoice_contact_box_number' => (
    is => 'rw',
    isa => 'Int',
    default => '85' 
);

has 'invoice_department_name' => (
    is => 'rw',
    isa => 'Str',
    default => 'Genome Institute'
);

has 'invoice_department_number' => (
    is => 'rw',
    isa => 'Int',
    default => 3533
);

has 'invoice_destination' => (
    is => 'rw',
    isa => INVOICE_DESTINATION_TYPE,
    required => 1
);

sub _build_invoice_date {
    my $self = shift;

    my @uniq_dates = uniq map{$_->date} @{$self->row_data};

    unless(scalar(@uniq_dates) == 1 ){
       die "multiple dates in spreadsheet: " . join(",",@uniq_dates);
    }
    return $uniq_dates[0];
}

sub _build_invoice_time {DateTime->now->strftime('%H%M%S')}

sub invoice_year {
    my $self = shift;
    my $date = $self->invoice_date;
    return substr($date,-2);
}
sub to_string {join('',map{$_->to_string} @{shift->billing_records});}

no Moose;
1;
