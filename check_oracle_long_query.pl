#!/usr/bin/perl
#
use strict;
use warnings;
use DBD::Oracle;

#option
my ($host,$port,$warning,$critical,$usage,$user)=("localhost",1521,30,600,0,"system");
my ($sid,$password,$checkuser);


while ($ARGV[0])
{
  $host       = $ARGV[1] if $ARGV[0] eq "-h";
  $port       = $ARGV[1] if $ARGV[0] eq "-P";
  $user       = $ARGV[1] if $ARGV[0] eq "-u";
  $password   = $ARGV[1] if $ARGV[0] eq "-p";
  $critical   = $ARGV[1] if $ARGV[0] eq "-l";
  $warning    = $ARGV[1] if $ARGV[0] eq "-w";
  $sid        = $ARGV[1] if $ARGV[0] eq "-D";
  $checkuser  = $ARGV[1] if $ARGV[0] eq "-c";
  $usage      = 1        if $ARGV[0] eq "--help";
  shift; shift;
}

if(!$sid || !$password || !$checkuser || $usage)
{
  &Help;
  exit;
}

# nagios rtn
use constant NAGIOS_OK       => 0;
use constant NAGIOS_WARNING  => 1;
use constant NAGIOS_CRITICAL => 2;
use constant NAGIOS_UNKNOWN  => 3;

my $DBH=&Connect_db;
my ($cBuf,$cAudsid,$wBuf,$wAudsid,$cSqlid,$wSqlid);

my @vUsers=split(/,/,$checkuser);

$checkuser="";
foreach my $vUser(@vUsers)
{
  my $buf=uc $vUser;
  $checkuser="$checkuser,'$buf'" if($checkuser);
  $checkuser="'$buf'" if(!$checkuser);
}

my $sesssql=qq{SELECT AUDSID,nvl(round((sysdate -SQL_EXEC_START) * 24 * 60 * 60,0),0) as ACTIVE_TIME,sql_id,username
               FROM v\$session 
               WHERE username in ($checkuser) 
               AND status='ACTIVE' order by ACTIVE_TIME desc};
#print $sesssql;
my $sth = $DBH->prepare($sesssql) || die DBI->errstr."$!";

$sth->execute() || die DBI->errstr."$!";

while ( my ($audsid,$time,$sqlid,$username) = $sth->fetchrow() )
{
  if($time >= $critical)
  {
    $cAudsid->{$audsid}=$sqlid;
    $cBuf->{$audsid}=$time;
    $cSqlid="$cSqlid,'$sqlid'" if($cSqlid);
    $cSqlid="'$sqlid'" if(!$cSqlid);
    next;
  }
  if($time >= $warning)
  {
    $wAudsid->{$audsid}=$sqlid;
    $wBuf->{$audsid}=$time;
    $wSqlid="$wSqlid,'$sqlid'" if($wSqlid);
    $wSqlid="'$sqlid'" if(!$wSqlid);
    next;
  }
}

#check 
if (!$cAudsid && !$wAudsid)
{
  print "OK";
  exit NAGIOS_OK;
}
#critical check
my $out;
if($cAudsid)
{
  my $vText=&Chktext($cSqlid);
  $out="CRITICAL: ";
  foreach my $id (keys(%$cAudsid))
  {
    $out="$out TIME= $cBuf->{$id} SQL_ID=$cAudsid->{$id} SQL= $vText->{$cAudsid->{$id}}";
  }
  print $out;
  exit NAGIOS_CRITICAL;
}
#warning check
if($wAudsid)
{
  my $vText=&Chktext($wSqlid);
  $out="WARNING: ";
  foreach my $id (keys(%$wAudsid))
  {
    $out="$out TIME= $wBuf->{$id} SQL_ID=$wAudsid->{$id} SQL= $vText->{$wAudsid->{$id}}";
  }
  print $out;
  exit NAGIOS_WARNING;
}

exit NAGIOS_UNKNOWN;

#check sqltext
sub Chktext
{
  my $sqltext;
  my $i=shift;
#  my $sql=qq{SELECT sql_id,LISTAGG(SQL_TEXT) WITHIN GROUP (ORDER BY PIECE) as SQL_TEXT FROM v\$sqltext WHERE PIECE <= 13 AND sql_id in ($i) GROUP BY sql_id};
  my $sql=qq{SELECT sql_id,nvl(SQL_TEXT,sql_id) FROM v\$sqltext WHERE PIECE =0 AND sql_id in ($i)};
  my $sth = $DBH->prepare($sql) || die DBI->errstr."$!";
#print $sql;
  $sth->execute() || die DBI->errstr."$!";

  while ( my ($ii,$text) = $sth->fetchrow() )
  {
    $sqltext->{$ii}=$text;
  }
  return $sqltext;
}

#DBconnect
sub Connect_db {
  my $db = join(';',"dbi:Oracle:host=$host","sid=$sid","port=$port");
  my $db_uid_passwd = "$user/$password";
  my $dbh = DBI->connect($db, $db_uid_passwd, "");
  return $dbh;
}

#Help
sub Help
{
	print << "EOS"
  -h [ip addr]  Hostname or Ip address[default $host]
  -P [port]     Port[default $port]
  -u [username] DBconnect Username[default $user] Must be able to access V$SESSION and V$SQLTEXT 
  -p [password] Password
  -D [sid]      SID
  -w [secs]     Warning seconds[default $warning]
  -l [secs]     Critical seconds[default $critical]
  -c [username or username,username,..] Monitored user or users
  --help        Show Help
EOS
}

