package WashU::Billing::MooseTypeLibrary;


use MooseX::Types -declare => [qw(DollarInt mmddyy AlmostValidDate ValidFile SupportedExtensions ArrayRefMax999 INVOICE_DESTINATION_TYPE)];
use Date::Manip;

 # import builtin types
use MooseX::Types::Moose qw/Str Num ArrayRef/;

subtype DollarInt, as  Num;
coerce DollarInt, from Str , via {s/\$|,//g; $_ = sprintf("%.2f",$_);$_; };

type mmddyy,
    where { /^[0-9]{2}[0-9]{2}[0-9]{2}$/},
    message {"Invalid date format!"};

subtype AlmostValidDate,
    as Str,
    where { /^20[0-9]{2}\/[0-9]{2}$/};

coerce mmddyy, 
    from AlmostValidDate,
    via {  UnixDate(DateCalc(DateCalc(ParseDate($_ ."/01") , " + 1 month" ), " - 1 day" ), "%m%d%y" ); };

subtype ValidFile , as Str , where { -e $_ }, 
  message { "Need a valid file_name. Spreadsheet $_ does not exist." };

subtype SupportedExtensions, as ValidFile , where {  /\.csv$/ }, 
  message { "Supported extension: csv " };

subtype ArrayRefMax999 , as ArrayRef, 
    where { scalar(@$_)  <= 999}, 
    message { "max limit of records per ID is 999" };


enum INVOICE_DESTINATION_TYPE , qw(internal external);


no Moose;
1;

__END__

=head1 NAME

       WashU::Billing::MooseTypeLibrary

     

=head1 DESCRIPTION

use MooseX::Types and exports type_definations to be consumed in other
packages in this application.

=head1 EXPORTS

=head2 DollarInt 

=cut 

=head2 mmddyy 

=cut 

=head2 AlmostValidDate 

=cut 

=head2 ValidFile 

=cut 

=head2 SupportedExtensions 

=cut 

=head2 ArrayRefMax999 

=cut 

=head2 INVOICE_DESTINATION_TYPE

=cut 
