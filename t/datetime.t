# -*- cperl -*-
use Test::More tests => 258;
use Test::Exception;

use warnings;

BEGIN {
    eval q{use TL qw(/dev/null)};
}

END {
}

my $dt;
ok($dt = $TL->newDateTime, 'newDateTime');
my $dt2;
$dt2 = $TL->newDateTime('2000-01-02 00:00:00');

#-- set ----------------------------
dies_ok {$dt->set(\123)} 'set die';
$dt->set('2000/01/02 03.04.05');
is($dt->toStr, '2000-01-02 03:04:05', 'generic ymdhms');

$dt->set('2000-01-02');
is($dt->toStr, '2000-01-02 00:00:00', 'generic ymd');

$dt->set('Fri Feb 17 11:24:41 JST 2006');
is($dt->toStr, '2006-02-17 11:24:41', 'date command');

$dt->set('17/Feb/2006:11:24:41 +0900');
is($dt->toStr, '2006-02-17 11:24:41', 'apache access_log');

$dt->set('Fri Feb 17 11:24:41 2006');
is($dt->toStr, '2006-02-17 11:24:41', 'apache error_log');

$dt->set('17-Feb-2006 11:24:41');
is($dt->toStr, '2006-02-17 11:24:41', 'apache index_log');

$dt->set('Fri, 17 Feb 06 11:24:41 +0900');
is($dt->toStr, '2006-02-17 11:24:41', 'RFC 822');

$dt->set('Fri, 17 Feb 2006 11:24:41 +0900');
is($dt->toStr, '2006-02-17 11:24:41', 'RFC 822 (4-digits year)');

$dt->set('Fri, 17-Feb-06 11:24:41 +0900');
is($dt->toStr, '2006-02-17 11:24:41', 'RFC 850');

$dt->set('Fri, 17-Feb-2006 11:24:41 +0900');
is($dt->toStr, '2006-02-17 11:24:41', 'RFC 850 (4-digits year)');

$dt->set('2006');
is($dt->toStr, '2006-01-01 00:00:00', 'W3C Year');

$dt->set('2006-02');
is($dt->toStr, '2006-02-01 00:00:00', 'W3C Year Month');

$dt->set('2006-02-17');
is($dt->toStr, '2006-02-17 00:00:00', 'W3C Year Month Day');

$dt->set('2006-02-17T11:24+09:00');
is($dt->toStr, '2006-02-17 11:24:00', 'W3C Year Month Day Hour Minute TZ');

$dt->set('2006-02-17T11:24:41+09:00');
is($dt->toStr, '2006-02-17 11:24:41', 'W3C Year Month Day Hour Minute Second TZ');

$dt->set('2006-02-17T11:24:41.55+09:00');
is($dt->toStr, '2006-02-17 11:24:41', 'W3C Year Month Day Hour Minute Second.s TZ');

$dt->set('@4000000043f529721590b6bc');
is($dt->toStr, '2006-02-17 10:33:52', 'TAI64N');

$dt->set('@40000000446442a90c03bcac');
#is($dt->toStr, '2006-02-17 10:33:52', 'TAI64N');


my $dt_1 = $dt->set('2000-04-31')->toStr;
my $dt_2 = $dt->set('2000-05-01')->toStr;
is($dt_1, $dt_2, 'auto-adjustment');

eval {
	$dt->set('2000-99-99');
};
ok($@, 'parse failure');

#-- clone ----------------------------
$dt->set('2000/01/02 03.04.05');
my $clone = $dt->clone;
is($dt->toStr, $clone->toStr, 'clone');

#-- setYear, Month, ... --------------
dies_ok {$dt->setYear} 'setYear die';
dies_ok {$dt->setYear(\123)} 'setYear die';
dies_ok {$dt->setYear('aaaa')} 'setYear die';

dies_ok {$dt->setMonth} 'setMonth die';
dies_ok {$dt->setMonth(\123)} 'setMonth die';
dies_ok {$dt->setMonth('aaaa')} 'setMonth die';
dies_ok {$dt->setMonth(0)} 'setMonth die';
dies_ok {$dt->setMonth(13)} 'setMonth die';
dies_ok {$dt->setMonth(-13)} 'setMonth die';

dies_ok {$dt->setDay} 'setDay die';
dies_ok {$dt->setDay(\123)} 'setDay die';
dies_ok {$dt->setDay('aaaa')} 'setDay die';
dies_ok {$dt->setDay(0)} 'setDay die';
dies_ok {$dt->setDay(50)} 'setDay die';
dies_ok {$dt->setDay(-50)} 'setDay die';

dies_ok {$dt->setHour} 'setHour die';
dies_ok {$dt->setHour(\123)} 'setHour die';
dies_ok {$dt->setHour('aaaa')} 'setHour die';
dies_ok {$dt->setHour(25)} 'setHour die';
dies_ok {$dt->setHour(-25)} 'setHour die';

dies_ok {$dt->setMinute} 'setMinute die';
dies_ok {$dt->setMinute(\123)} 'setMinute die';
dies_ok {$dt->setMinute('aaaa')} 'setMinute die';
dies_ok {$dt->setMinute(61)} 'setMinute die';
dies_ok {$dt->setMinute(-61)} 'setMinute die';

dies_ok {$dt->setSecond} 'setSecond die';
dies_ok {$dt->setSecond(\123)} 'setSecond die';
dies_ok {$dt->setSecond('aaaa')} 'setSecond die';
dies_ok {$dt->setSecond(61)} 'setSecond die';
dies_ok {$dt->setSecond(-61)} 'setSecond die';

$dt->set('2000/01/02 03.04.05');
$dt->setYear(1999);
is($dt->toStr, '1999-01-02 03:04:05', 'setYear');

$dt->set('2000/01/02 03.04.05');
$dt->setMonth(1);
$dt->setMonth(-1);
is($dt->toStr, '2000-12-02 03:04:05', 'setMonth');

$dt->set('2000/01/02 03.04.05');
$dt->setDay(-1);
is($dt->toStr, '2000-01-31 03:04:05', 'setDay');

$dt->set('2000/01/02 03.04.05');
$dt->setHour(-1);
is($dt->toStr, '2000-01-02 23:04:05', 'setHour');

$dt->set('2000/01/02 03.04.05');
$dt->setMinute(-1);
is($dt->toStr, '2000-01-02 03:59:05', 'setMinute');

$dt->set('2000/01/02 03.04.05');
$dt->setSecond(-1);
is($dt->toStr, '2000-01-02 03:04:59', 'setSecond');

#-- setTimeZone ------------------------
dies_ok {$dt->setTimeZone(\1)} 'setTimeZone die';
dies_ok {$dt->setTimeZone('aaa')} 'setTimeZone die';

$dt->setTimeZone(1);
is($dt->getTimeZone, 1, 'setTimeZone(1)');

$dt->setTimeZone('-0300');
is($dt->getTimeZone, -3, 'getTimeZone("-0300")');

$dt->setTimeZone('JST');
is($dt->getTimeZone, 9, 'getTimeZone("JST")');

#-- setEpoch, ... --------------
dies_ok {$dt->setEpoch} 'setEpoch die';
dies_ok {$dt->setEpoch(\123)} 'setEpoch die';
dies_ok {$dt->setEpoch('aaaa')} 'setEpoch die';

$dt->setEpoch(666);
is($dt->getEpoch, 666, 'setEpoch / getEpoch');

dies_ok {$dt->setJulianDay} 'setJulianDay die';
dies_ok {$dt->setJulianDay(\123)} 'setJulianDay die';
dies_ok {$dt->setJulianDay('aaaa')} 'setJulianDay die';

$dt->setJulianDay(666);
is($dt->getJulianDay, 666, 'setJulianDay / getJulianDay');

#-- getSecond, ... ------------
$dt->set('Mon Feb 20 16:45:01 JST 2006');
is($dt->getSecond, 01, 'getSecond');
is($dt->getMinute, 45, 'getMinute');
is($dt->getHour,   16, 'getHour');
is($dt->getDay,    20, 'getDay');
is($dt->getMonth,  02, 'getMonth');
is($dt->getYear, 2006, 'getYear');
is($dt->getWday,    1, 'getWday');
is($dt->getAnimal, 10, 'getAnimal');

#-- holiday ------------------------
ok($dt->getAllHolidays, 'getAllHolidays');
ok($dt->isHoliday || 1, 'isHoliday');
ok($dt->getHolidayName || 1, 'getHolidayName');

$dt->set('2000-12-23');
ok($dt->isHoliday, '2000-12-23 is a holiday');
is($dt->getHolidayName, '天皇誕生日', '2000-12-23 is a birthday of Emperor');

$dt->set('2006-07-14');
is($dt->isHoliday(0), undef , 'FRI isHoliday(0)');
is($dt->isHoliday(1), undef , 'FRI isHoliday(1)');
is($dt->isHoliday(2), undef , 'FRI isHoliday(2)');
$dt2 = $dt->addBusinessDay(1);
is($dt2->getDay, 18 , 'FRI addBusinessDay(1)');
$dt2 = $dt->addBusinessDay(1,0);
is($dt2->getDay, 18 , 'FRI addBusinessDay(1,0)');
$dt2 = $dt->addBusinessDay(1,1);
is($dt2->getDay, 15 , 'FRI addBusinessDay(1,0)');
$dt2 = $dt->addBusinessDay(1,2);
is($dt2->getDay, 15 , 'FRI addBusinessDay(1,0)');
$dt2 = $dt->addBusinessDay(2);
is($dt2->getDay, 18 , 'FRI addBusinessDay(1)');
$dt2 = $dt->addBusinessDay(2,0);
is($dt2->getDay, 18 , 'FRI addBusinessDay(1,0)');
$dt2 = $dt->addBusinessDay(2,1);
is($dt2->getDay, 18 , 'FRI addBusinessDay(1,0)');
$dt2 = $dt->addBusinessDay(2,2);
is($dt2->getDay, 16 , 'FRI addBusinessDay(1,0)');

$dt->set('2006-07-15');
is($dt->isHoliday(0), 1 , 'SAT isHoliday(0)');
is($dt->isHoliday(1), undef , 'SAT isHoliday(1)');
is($dt->isHoliday(2), undef , 'SAT isHoliday(2)');
$dt->set('2006-07-16');
is($dt->isHoliday(0), 1 , 'SUN isHoliday(0)');
is($dt->isHoliday(1), 1 , 'SUN isHoliday(1)');
is($dt->isHoliday(2), undef , 'SUN isHoliday(2)');
$dt->set('2006-07-17');
is($dt->isHoliday(0), 1 , 'SAT isHoliday(0)');
is($dt->isHoliday(1), 1 , 'SAT isHoliday(1)');
is($dt->isHoliday(2), 1 , 'SAT isHoliday(2)');


#-- isLeapYear --------------------
$dt->setYear(2004);
is($dt->isLeapYear, 1, 'isLeapYear -- 2004');

$dt->setYear(2005);
is($dt->isLeapYear, undef, 'isLeapYear -- 2005');

#-- calendar ----------------------
dies_ok {$dt->getCalendarMatrix(type => {})} 'getCalendarMatrix die';
dies_ok {$dt->getCalendarMatrix(\123)} 'getCalendarMatrix die';
dies_ok {$dt->getCalendarMatrix(type => 'normal', begin => 'wed')} 'getCalendarMatrix die';

$dt->set('2006-10-01');
ok($dt->getCalendar, 'getCalendar');
ok($dt->getCalendarMatrix(type => 'normal', begin => 'sun'), 'getCalendarMatrix');
ok($dt->getCalendarMatrix(type => 'fixed', begin => 'sun'), 'getCalendarMatrix');
$dt->set('2005-12-01');
ok($dt->getCalendarMatrix(type => 'fixed', begin => 'mon'), 'getCalendarMatrix');

#-- spanSecond, ... --------------
dies_ok {$dt->spanSecond} 'spanSecond die';
$dt->set('2000-01-02 03:04:05');
my $other = $dt->clone->set('2000-01-02 03:04:10');
is($dt->spanSecond($other), 5, 'spanSecond');
is($dt->spanSecond('2000-01-02 03:04:00'), -5, 'spanSecond');

dies_ok {$dt->spanMinute} 'spanMinute die';
$other->set('2000-01-02 03:14:05');
is($dt->spanMinute($other), 10, 'spanMinute');
is($dt->spanMinute('2000-01-02 03:00:05'), -4, 'spanMinute');

dies_ok {$dt->spanHour} 'spanHour die';
$other->set('2000-01-02 05:14:05');
is($dt->spanHour($other), 2, 'spanHour');
is($dt->spanHour('2000-01-02 00:14:05'), -3, 'spanHour');

dies_ok {$dt->spanDay} 'spanDay die';
$other->set('2000-01-12 05:14:05');
is($dt->spanDay($other), 10, 'spanDay');
is($dt->spanDay('2000-01-01 05:14:05'), -1, 'spanDay');

dies_ok {$dt->spanMonth} 'spanMonth die';
$other->set('2000-03-12 05:14:05');
is($dt->spanMonth($other), 2, 'spanMonth');
is($dt->spanMonth('1999-12-01 00:00:00'), -1, 'spanMonth (negative)');

dies_ok {$dt->spanYear} 'spanYear die';
$other->set('2003-03-12 05:14:05');
is($dt->spanYear($other), 3, 'spanYear');
is($dt->spanYear('1999-03-12 05:14:05'), -1, 'spanYear');

#-- addSecond, ... --------------
dies_ok {$dt->addSecond} 'addSecond die';
dies_ok {$dt->addSecond(\123)} 'addSecond die';
dies_ok {$dt->addSecond('aaa')} 'addSecond die';
$dt->set('2000-01-02 03:04:05');
my $added = $dt->addSecond(5);
is($added->toStr, '2000-01-02 03:04:10', 'addSecond');

dies_ok {$dt->addMinute} 'addMinute die';
dies_ok {$dt->addMinute(\123)} 'addMinute die';
dies_ok {$dt->addMinute('aaa')} 'addMinute die';
$added = $dt->addMinute(56);
is($added->toStr, '2000-01-02 04:00:05', 'addMinute');

dies_ok {$dt->addHour} 'addHour die';
dies_ok {$dt->addHour(\123)} 'addHour die';
dies_ok {$dt->addHour('aaa')} 'addHour die';
$added = $dt->addHour(5);
is($added->toStr, '2000-01-02 08:04:05', 'addHour');

dies_ok {$dt->addDay} 'addDay die';
dies_ok {$dt->addDay(\123)} 'addDay die';
dies_ok {$dt->addDay('aaa')} 'addDay die';
$added = $dt->addDay(5);
is($added->toStr, '2000-01-07 03:04:05', 'addDay');

dies_ok {$dt->addMonth} 'addMonth die';
dies_ok {$dt->addMonth(\123)} 'addMonth die';
dies_ok {$dt->addMonth('aaa')} 'addMonth die';
$added = $dt->addMonth(5);
is($added->toStr, '2000-06-02 03:04:05', 'addMonth(5)');

dies_ok {$dt->addMonth} 'addMonth die';
dies_ok {$dt->addMonth(\123)} 'addMonth die';
dies_ok {$dt->addMonth('aaa')} 'addMonth die';
$added = $dt->addMonth(13);
is($added->toStr, '2001-02-02 03:04:05', 'addMonth(10)');

$dt->set('2000-01-31 03:04:05');
dies_ok {$dt->addMonth} 'addMonth die';
dies_ok {$dt->addMonth(\123)} 'addMonth die';
dies_ok {$dt->addMonth('aaa')} 'addMonth die';
$added = $dt->addMonth(-7);
is($added->toStr, '1999-06-30 03:04:05', 'addMonth(-7)');

$dt->set('2004-02-29 03:04:05');
dies_ok {$dt->addYear} 'addYear die';
dies_ok {$dt->addYear(\123)} 'addYear die';
dies_ok {$dt->addYear('aaa')} 'addYear die';
$added = $dt->addYear(5);
is($added->toStr, '2009-02-28 03:04:05', 'addYear');

#-- nextDa, ... --------
$dt->set('2000-01-02 03:04:05');
$dt = $dt->nextDay;
is($dt->toStr, '2000-01-03 03:04:05', 'nextDay');

$dt = $dt->prevDay;
is($dt->toStr, '2000-01-02 03:04:05', 'prevDay');

$dt = $dt->firstDay;
is($dt->toStr, '2000-01-01 03:04:05', 'firstDay');

$dt = $dt->lastDay;
is($dt->toStr, '2000-01-31 03:04:05', 'lastDay');

#-- toStr --------------
dies_ok {$dt->toStr('aaa')} 'toStr die';

$dt->set('2000-01-02 03:04:05');
$dt->setTimeZone(9);
is($dt->toStr, '2000-01-02 03:04:05', 'toStr()');
is($dt->toStr('mysql'), '2000-01-02 03:04:05', 'toStr("mysql")');
is($dt->toStr('rfc822'), 'Sun, 02 Jan 2000 03:04:05 +0900', 'toStr("rfc822")');
is($dt->toStr('rfc850'), 'Sun, 02-Jan-2000 03:04:05 +0900', 'toStr("rfc850")');
is($dt->toStr('w3c'), '2000-01-02T03:04:05+09:00', 'toStr("w3c")');

#-- strFormat ----------
$dt->set('2000-01-02 03:04:05');
$dt->setTimeZone(9);

is($dt->strFormat('%a'), 'Sun', 'strFormat("%a")');
is($dt->strFormat('%A'), 'Sunday', 'strFormat("%A")');
is($dt->strFormat('%J'), '日', 'strFormat("%J")');
is($dt->strFormat('%b'), 'Jan', 'strFormat("%b")');
is($dt->strFormat('%B'), 'January', 'strFormat("%B")');
is($dt->strFormat('%_B'), '睦月', 'strFormat("%_B")');
is($dt->strFormat('%d'), '02', 'strFormat("%d")');
is($dt->strFormat('%_d'), '2', 'strFormat("%_d")');
is($dt->strFormat('%m'), '01', 'strFormat("%m")');
is($dt->strFormat('%_m'), '1', 'strFormat("%_m")');
is($dt->strFormat('%w'), '0', 'strFormat("%w")');
is($dt->strFormat('%y'), '00', 'strFormat("%y")');
is($dt->strFormat('%Y'), '2000', 'strFormat("%Y")');
is($dt->strFormat('%_Y'), '平成12年', 'strFormat("%_Y") [0]');

$dt->set('1989-01-07 00:00:00');
is($dt->strFormat('%_Y'), '昭和64年', 'strFormat("%_Y") [1]');

$dt->set('1989-01-08 00:00:00');
is($dt->strFormat('%_Y'), '平成元年', 'strFormat("%_Y") [2]');

$dt->set('2000-01-02 03:04:05');
is($dt->strFormat('%H'), '03', 'strFormat("%H")');
is($dt->strFormat('%_H'), '3', 'strFormat("%_H")');

is($dt->strFormat('%I'), '03', 'strFormat("%I") [0]');
is($dt->strFormat('%_I'), '3', 'strFormat("%_I") [0]');

$dt->set('2000-01-02 13:04:05');
is($dt->strFormat('%I'), '01', 'strFormat("%I") [1]');
is($dt->strFormat('%_I'), '1', 'strFormat("%_I") [1]');

$dt->set('2000-01-02 03:04:05');
is($dt->strFormat('%P'), 'a.m.', 'strFormat("%P") [0]');
is($dt->strFormat('%_P'), '午前', 'strFormat("%_P") [0]');

$dt->set('2000-01-02 13:04:05');
is($dt->strFormat('%P'), 'p.m.', 'strFormat("%P") [1]');
is($dt->strFormat('%_P'), '午後', 'strFormat("%_P") [1]');

$dt->set('2000-01-02 03:04:05');
is($dt->strFormat('%M'), '04', 'strFormat("%M")');
is($dt->strFormat('%_M'), '4', 'strFormat("%_M")');
is($dt->strFormat('%S'), '05', 'strFormat("%S")');
is($dt->strFormat('%_S'), '5', 'strFormat("%_S")');
is($dt->strFormat('%E'), '辰', 'strFormat("%E")');
is($dt->strFormat('%z'), '+0900', 'strFormat("%z")');
is($dt->strFormat('%_z'), '+09:00', 'strFormat("%_z")');
is($dt->strFormat('%Z'), 'JST', 'strFormat("%Z")');
is($dt->strFormat('%T'), '03:04:05', 'strFormat("%T")');
is($dt->strFormat('%%'), '%', 'strFormat("%%")');

#-- parseFormat ----------
dies_ok {$dt->parseFormat} 'parseFormat die';
dies_ok {$dt->parseFormat(\123)} 'parseFormat die';
dies_ok {$dt->parseFormat('%Y %a')} 'parseFormat die';
dies_ok {$dt->parseFormat('%Y %a',\123)} 'parseFormat die';
dies_ok {$dt->parseFormat('%sa', '2006 Sun')} 'parseFormat die';
dies_ok {$dt->parseFormat('%Y %Y', '2006 2007')} 'parseFormat die';
dies_ok {$dt->parseFormat('%Y %H %I', '2006 20 12')} 'parseFormat die';
dies_ok {$dt->parseFormat('%Y %P', '2006 am')} 'parseFormat die';
dies_ok {$dt->parseFormat('%H', '20')} 'parseFormat die';
dies_ok {$dt->parseFormat('%Y %w', '2006 am')} 'parseFormat die';

$dt->setTimeZone(9);
$dt->parseFormat('%Y %a', '2006 Sun');
is($dt->toStr, '2006-01-01 00:00:00', 'parseFormat("%a")');

$dt->parseFormat('%Y %A', '2006 Sunday');
is($dt->toStr, '2006-01-01 00:00:00', 'parseFormat("%A")');

$dt->parseFormat('%Y %J', '2006 日');
is($dt->toStr, '2006-01-01 00:00:00', 'parseFormat("%J")');

$dt->parseFormat('%Y %b', '2006 Sep');
is($dt->toStr, '2006-09-01 00:00:00', 'parseFormat("%b")');

$dt->parseFormat('%Y %B', '2006 September');
is($dt->toStr, '2006-09-01 00:00:00', 'parseFormat("%B")');

$dt->parseFormat('%Y %_B', '2006 神無月');
is($dt->toStr, '2006-10-01 00:00:00', 'parseFormat("%_B")');

$dt->parseFormat('%Y %d', '2006 10');
is($dt->toStr, '2006-01-10 00:00:00', 'parseFormat("%d")');

$dt->parseFormat('%Y %_d', '2006 9');
is($dt->toStr, '2006-01-09 00:00:00', 'parseFormat("%_d")');

$dt->parseFormat('%Y %m', '2006 11');
is($dt->toStr, '2006-11-01 00:00:00', 'parseFormat("%m")');

$dt->parseFormat('%Y %_m', '2006 2');
is($dt->toStr, '2006-02-01 00:00:00', 'parseFormat("%_m")');

$dt->parseFormat('%Y %w', '2006 0');
is($dt->toStr, '2006-01-01 00:00:00', 'parseFormat("%w")');

$dt->parseFormat('%y', '96');
is($dt->toStr, '1996-01-01 00:00:00', 'parseFormat("%y")');

$dt->parseFormat('%Y', '2006');
is($dt->toStr, '2006-01-01 00:00:00', 'parseFormat("%Y")');

$dt->parseFormat('%_Y', '平成元年');
is($dt->toStr, '1989-01-01 00:00:00', 'parseFormat("%_Y") [0]');

$dt->parseFormat('%_Y', '平成2年');
is($dt->toStr, '1990-01-01 00:00:00', 'parseFormat("%_Y") [1]');

$dt->parseFormat('%Y %H', '2006 02');
is($dt->toStr, '2006-01-01 02:00:00', 'parseFormat("%H")');

$dt->parseFormat('%Y %_H', '2006 2');
is($dt->toStr, '2006-01-01 02:00:00', 'parseFormat("%_H")');

$dt->parseFormat('%Y %I %P', '2006 02 p.m.');
is($dt->toStr, '2006-01-01 14:00:00', 'parseFormat("%I %P")');

$dt->parseFormat('%Y %_I %_P', '2006 2 午前');
is($dt->toStr, '2006-01-01 02:00:00', 'parseFormat("%_I %_P")');

$dt->parseFormat('%Y %M', '2006 05');
is($dt->toStr, '2006-01-01 00:05:00', 'parseFormat("%M")');

$dt->parseFormat('%Y %_M', '2006 5');
is($dt->toStr, '2006-01-01 00:05:00', 'parseFormat("%_M")');

$dt->parseFormat('%Y %S', '2006 05');
is($dt->toStr, '2006-01-01 00:00:05', 'parseFormat("%S")');

$dt->parseFormat('%Y %_S', '2006 5');
is($dt->toStr, '2006-01-01 00:00:05', 'parseFormat("%_S")');

$dt->parseFormat('%Y %E', '2006 戌');
is($dt->toStr, '2006-01-01 00:00:00', 'parseFormat("%E")');

$dt->parseFormat('%Y %z', '2006 -0900');
is($dt->getTimeZone, -9, 'parseFormat("%z")');

$dt->parseFormat('%Y %_z', '2006 Z');
is($dt->getTimeZone, 0, 'parseFormat("%_z")');

$dt->parseFormat('%Y %Z', '2006 JST');
is($dt->getTimeZone, 9, 'parseFormat("%Z")');

$dt->parseFormat('%Y %T', '2006 05:04:03');
is($dt->toStr, '2006-01-01 05:04:03', 'parseFormat("%T")');

$dt->parseFormat('%Y %%', '2006 %');
is($dt->toStr, '2006-01-01 00:00:00', 'parseFormat("%%")');

#-- etc ----------
dies_ok {$dt->__parseRFC822TimeZone('aaaaaaaa')} '__parseRFC822TimeZone die';
dies_ok {$dt->__parseW3CTimeZone('aaaaaaaa')} '__parseW3CTimeZone die';
dies_ok {$dt->__parseJPYear('aaaaaaaa')} '__parseJPYear die';

is($dt->__getRFC822TimeZone(0), 'UT' , '__getRFC822TimeZone (GMT)');
is($dt->__parseRFC822TimeZone('GMT'), '0' , '__gparseRFC822TimeZone (GMT)');
is($dt->__getW3CTimeZone(0), 'Z' , '__getW3CTimeZone (0)');
is($dt->__getTZByName('nzdt'), '46800' , '__getTZByName (nzdt)');
is($dt->__getTZNameBySec(46800), 'nzdt' , '__getTZNameBySec (46800)');
is($dt->__getTZNameBySec('aaaaaaaa'), undef , '__getTZNameBySec (aaaaaaaa)');

ok($dt->__lastDayOfMonth(1), '__lastDayOfMonth');
