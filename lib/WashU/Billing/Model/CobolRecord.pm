package WashU::Billing::Model::CobolRecord;
use Moose; 
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use List::AllUtils qw(sum uniq);
use WashU::Billing::Model::CobolField;
use warnings FATAL => qw(all);

use constant FIELD_DEFINITION => [
            'record_code',
            'description',
            'requirement_type',
            'field_type',
            'position',
            'field_length',
            ];

use constant FIELD_TYPE_MAP => {
    DT => 'Int',
    N0 => 'Int',
    AN => 'Str',
    N2 => 'Num'
};

enum RECORD_CODE => qw/000 011 010 020 030 040 050 999/;
has record_code => (
   is => 'rw',
   isa => 'RECORD_CODE',
   required => 1,
); 

has field_data => (
   is => 'rw',
   isa => 'ArrayRef[WashU::Billing::Model::CobolField]',
   trigger => 
    sub {
        my ($self, $fd) = @_;
        if($self->field_data_count != scalar(@$fd)){
            die "Field Data is length ". scalar(@$fd) .  " but constrained length is: " . $self->field_data_count;
        }

        my $sum = sum map{$_->field_length} @$fd;
        unless($sum == $self->record_length){
           die "record field_length sum: $sum does not equal mandatory record length: " .$self->record_length; 
        }

        $sum = sum map{length($_->value)} @$fd;
        unless($sum == $self->record_length){
           die "record value sum: $sum does not equal mandatory record length: " .$self->record_length; 
        }

        my %pos ;
        for my $f (@$fd){
            $pos{$_}++ for ($f->position .. ($f->position + $f->field_length -1));
        }
        
        for(keys %pos){
            if($pos{$_} > 1){
                die "position $_ has multiple values... you screwed up your indexing";
            }
        }

        return 1;
    },
   lazy_build => 1,
);

has field_data_count => (
   is => 'rw',
   isa => 'Int',
);

sub BUILD {
    my $self =shift;
    $self->field_data_count(scalar($self->field_data_definitions));
}

sub record_length { 80 }

sub to_string { join('',map{$_->value} @{shift->field_data}). "\n"; }

sub set_field_data {
    my ($self,%p ) = @_;
    $p{record_code} = $self->record_code;

    my @data = 
        map {
            $_->{value} = (defined $p{$_->{description}})?
             delete $p{$_->{description}}:
             '';
             $_;

        } $self->field_data_definitions;

    die "Extra descriptions left in the contructor hash indicating a mismapping: ". join(",", keys %p) if(%p);


    $self->field_data([map{WashU::Billing::Model::CobolField->new(%$_)} @data]);
}

#special comments:
#
# 010,control_number,Optional,AN,55,6      type modified to: NO
# 010,ido_admin_number,Optional,AN,61,6    type modified to: NO

# 020,cr_acct_ledger_class,Mandatory,N0,7,2
# 020,cr_acct_department,Mandatory,N0,9,4
# 020,cr_acct_budget_code,Mandatory,N0,13,2
# 020,cr_acct_object_code,Mandatory,N0,15,2
# 020,cr_acct_sr_code,Optional,AN,17,2
# 020,cr_acct_fund_number,Optional,AN,19,6

# 030,db_acct_ledger_class,Optional,N0,7,2
# 030,db_acct_department,Optional,N0,9,4
# 030,db_acct_budget_code,Optional,N0,13,2
# 030,db_acct_object_code,Optional,N0,15,2
# 030,db_acct_sr_code,Optional,AN,17,2
# 030,db_acct_fund_number,Optional,AN,19,6

use constant RECORD_CODE_TO_FIELD_DEFINITION_VALUES => { 
 '000' => [
    [qw/000 record_code Mandatory N0 1 3/],
    [qw/000 department_number Mandatory N0 4 6/],
    [qw/000 date_batch_sent Mandatory DT 10 6/],
    [qw/000 time_batch_sent Mandatory N0 16 6/],
    [qw/000 department_name Mandatory AN 22 25/],
    [qw/000 contact_person Mandatory AN 47 25/],
    [qw/000 contact_phone_number Mandatory AN 72 8/],
    [qw/000 filler Unused AN 80 1/],
],
 '010' => [
    [qw/010 record_code Mandatory N0 1 3/],
    [qw/010 document_type Mandatory AN 4 2/],
    [qw/010 billing_dept Mandatory N0 6 6/],
    [qw/010 contact_name Mandatory AN 12 25/],
    [qw/010 invoice_date Mandatory DT 37 6/],
    [qw/010 contact_box_number Mandatory N0 43 4/],
    [qw/010 contact_phone_number Mandatory AN 47 8/],
    [qw/010 control_number Optional N0 55 6/],
    [qw/010 ido_admin_number Optional N0 61 6/],
    [qw/010 documentation_with Mandatory AN 67 1/],
    [qw/010 fiscal_year Mandatory N0 68 2/],
    [qw/010 filler Unused AN 70 11/],
],
 '011' => [
    [qw/011 record_code Mandatory N0 1 3/],
    [qw/011 send_to_dept Mandatory N0 4 6/],
    [qw/011 send_to_dept_name Optional AN 10 25/],
    [qw/011 vendor_dept Mandatory N0 35 6/],
    [qw/011 vendor_dept_name Optional AN 41 25/],
    [qw/011 filler Optional AN 66 1/],
    [qw/011 invoice_amount Mandatory N2 67 10/],
    [qw/011 invoice_amount_sign Optional AN 77 1/],
    [qw/011 filler Unused AN 78 3/],
],
 '020' => [
    [qw/020 record_code Mandatory N0 1 3/],
    [qw/020 sequence_number Optional N0 4 3/],
    [qw/020 credit_account_number Mandatory AN 7 18/],
    [qw/020 filler Unused AN 25 1/],
    [qw/020 credit_amount Mandatory N2 26 10/],
    [qw/020 credit_amount_sign Optional AN 36 1/],
    [qw/020 filler Unused AN 37 44/],
],
 '030' => [
    [qw/030 record_code Mandatory N0 1 3/],
    [qw/030 sequence_number Optional N0 4 3/],
    [qw/030 debit_acct_number Optional AN 7 18/],
    [qw/030 filler Unused AN 25 1/],
    [qw/030 debit_amount Optional N2 26 10/],
    [qw/030 debit_amount_sign Optional AN 36 1/],
    [qw/030 filler Unused AN 37 44/],
],
 '040' => [
    [qw/040 record_code Mandatory N0 1 3/],
    [qw/040 sequence_number Optional N0 4 3/],
    [qw/040 item_number Optional N0 7 3/],
    [qw/040 item_quantity Optional AN 10 4/],
    [qw/040 item_date Optional DT 14 6/],
    [qw/040 item_description Optional AN 20 48/],
    [qw/040 filler Unused AN 68 1/],
    [qw/040 item_amount Mandatory N2 69 10/],
    [qw/040 item_amount_sign Optional AN 79 1/],
    [qw/040 filler Unused AN 80 1/],
],
 '050' => [
    [qw/050 record_code Mandatory N0 1 3/],
    [qw/050 received_by_name Optional AN 4 64/],
    [qw/050 filler Unused AN 68 13/],
],
 '999' => [
    [qw/999 record_code Mandatory N0 1 3/],
    [qw/999 department_number Mandatory N0 4 6/],
    [qw/999 date_batch_sent Mandatory DT 10 6/],
    [qw/999 time_batch_sent Mandatory N0 16 6/],
    [qw/999 document_count Mandatory N0 22 6/],
    [qw/999 filler Unused AN 28 53/],
]
};

sub field_data_definitions {
    my ( $self, %p ) = @_;
    my $record_code = $p{record_code} ? $p{record_code} : $self->record_code;

#this is a fancy weave of key value pairs defined in two constant arrays
      my @array;
      for my $ref (@{ RECORD_CODE_TO_FIELD_DEFINITION_VALUES->{$record_code} }){
          my %foo;
          @foo{@{FIELD_DEFINITION()}} = @$ref;
          $foo{field_type} = FIELD_TYPE_MAP->{ $foo{field_type} };
          push @array, \%foo;
      }

      return @array;
}

sub find_field_data_definition_by_description {
    my ($class, $description) = @_;

    my @hits = grep{$_->[1] eq $description }  map{@{RECORD_CODE_TO_FIELD_DEFINITION_VALUES->{$_}} } keys %{RECORD_CODE_TO_FIELD_DEFINITION_VALUES()};
    if(scalar(@hits) > 1) {
        die "description: $description has multiple definitions";

    }
    my %foo;
    @foo{@{FIELD_DEFINITION()}} = @{$hits[0]};
    $foo{field_type} = FIELD_TYPE_MAP->{ $foo{field_type} };
    return \%foo;
}

__PACKAGE__->meta->make_immutable;
1;
