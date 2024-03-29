# -----------------------------------------------------------------------------
# TL::DB - DBIのラッパ
# -----------------------------------------------------------------------------
package TL::DB;
use strict;
use warnings;
use TL;
require Time::HiRes;

sub _PRE_REQUEST_HOOK_PRIORITY() { -1_000_000 } # 順序は問わない
sub _POST_REQUEST_HOOK_PRIORITY() { -1_000_000 } # セッションフックの後
sub _TERM_HOOK_PRIORITY() { -1_000_000 } # セッションフックの後

our $INSTANCES = {}; # グループ名 => インスタンス

1;

sub _getInstance {
	my $class = shift;
	my $group = shift;

	if(!defined($group)) {
		$group = 'DB';
	} elsif(ref($group)) {
		die "TL#getDB, ARG[1] was Ref.\n";
	}

	my $obj = $INSTANCES->{$group};
	if(!$obj) {
		die "TL#getDB, DB [$group] was not specified in the startCgi() / errorTrap().\n";
	}

	$obj;
}

sub connect {
	my $this = shift;

	# 全てのDBコネクションの接続を確立する．
	foreach my $dbh (values %{$this->{dbname}}) {
		if(!$dbh->ping) {
			$dbh->connect($this->{type});
		}
	}

	$this;
}

sub disconnect {
	my $this = shift;

	foreach my $dbh (values %{$this->{dbname}}) {
		$dbh->disconnect;
	}

	$this;
}

sub begin {
	my $this = shift;
	my $setname = shift;

	my $set = $this->_getDbSetName($setname);

	if(my $trans = $this->{trans_dbh}) {
		my $trans_set = $trans->getSetName;
		if($trans_set ne $set) {
			die __PACKAGE__."#begin, attempted to begin a transaction on DB Set [$set] but".
				" another DB Set [$trans_set] were already in transaction.".
				" Commit or rollback it before begin another one.\n";
		} else {
			die __PACKAGE__."#begin, already in transaction.";
		}
	}

	my $begintime = [Time::HiRes::gettimeofday()];

	my $dbh = $this->{dbh}{$set};
	$dbh->begin;

	my $elapsed = Time::HiRes::tv_interval($begintime);

	my $sql = $this->__nameQuery('BEGIN', $dbh);

	$TL->getDebug->_dbLog(
		group   => $this->{group},
		set     => $dbh->getSetName,
		db      => $dbh->getGroup,
		id      => -1,
		query   => $sql,
		params  => [],
		elapsed => $elapsed,
	);

	$this->{trans_dbh} = $dbh;
	$this;
}

sub rollback {
	my $this = shift;

	my $dbh = $this->{trans_dbh};
	if(!defined($dbh)) {
		die __PACKAGE__."#rollback, not in transaction.\n";
	}

	my $begintime = [Time::HiRes::gettimeofday()];

	$dbh->rollback;

	my $elapsed = Time::HiRes::tv_interval($begintime);

	my $sql = $this->__nameQuery('ROLLBACK', $dbh);

	$TL->getDebug->_dbLog(
		group   => $this->{group},
		set     => $dbh->getSetName,
		db      => $dbh->getGroup,
		id      => -1,
		query   => $sql,
		params  => [],
		elapsed => $elapsed,
	);

	$this->{trans_dbh} = undef;
	$this;
}

sub commit {
	my $this = shift;

	my $dbh = $this->{trans_dbh};
	if (!defined($dbh)) {
		die __PACKAGE__."#commit, not in transaction.\n";
	}

	my $begintime = [Time::HiRes::gettimeofday()];

	$dbh->commit;

	my $elapsed = Time::HiRes::tv_interval($begintime);

	my $sql = $this->__nameQuery('COMMIT', $dbh);

	$TL->getDebug->_dbLog(
		group   => $this->{group},
		set     => $dbh->getSetName,
		db      => $dbh->getGroup,
		id      => -1,
		query   => $sql,
		params  => [],
		elapsed => $elapsed,
	);

	$this->{trans_dbh} = undef;
	$this;
}

sub setDefaultSet {
	my $this = shift;
	my $setname = shift;

	if(defined($setname)) {
		$this->{default_set} = $this->_getDbSetName($setname);
	} else {
		$this->{default_set} = undef;
	}

	$this;
}

sub execute {
	my $this = shift;
	my $dbset = shift;
	if(ref($dbset)) {
		$dbset = $$dbset;
	} else {
		unshift(@_, $dbset);
		$dbset = undef;
	}
	my $sql = shift;
	my $sql_backup = $sql; # デバッグ用

	if(!defined($sql)) {
		die __PACKAGE__."#execute, ARG[1] was undef.\n";
	} elsif(ref($sql)) {
		die __PACKAGE__."#execute, ARG[1] was Ref.\n";
	} elsif($sql =~ m/^\s*(LOCK|UNLOCK|BEGIN|ROLLBACK|COMMIT)/i) {
		# これらのSQL文をexecuteすると整合性が失われる。
		die __PACKAGE__."#execute, attempted to execute [$1] statement directly.".
			" Use particular methods not to ruin consistency of TL::DB totally.\n";
	}

	my @params;
	if($sql =~ m/\?\?/) {
		# パラメータの中からARRAY Refのものを全て抜き出し、 ?? を ?, ?, ... に置換
		foreach my $param (@_) {
			if(!ref($param)) {
				push @params, $param;
			} elsif(ref($param) eq 'ARRAY') {
				if(@$param == 0) {
					# 0要素の配列があってはならない。
					die __PACKAGE__."#execute, some argument was an empty array.\n";
				}

				my $n_params = @$param;

				if(ref($param->[-1]) eq 'SCALAR') {
					# 最後の要素がSCALAR Refなら、それは全体の型指定。

					my $type = $param->[-1];
					$n_params--;

					for(my $i = 0; $i < @$param - 1; $i++) {
						if(ref($param->[$i]) eq 'ARRAY') {
							# これは個別に型が指定されているので、デフォルトの型を適用しない。
							push @params, $param->[$i];
						} else {
							push @params, [$param->[$i], $type];
						}
					}
				} else {
					push @params, @$param;
				}

				unless($sql =~ s{\?\?}{
					join(', ', ('?') x $n_params);
				}e) {
					die __PACKAGE__."#execute, the number of `??' is fewer than ARRAY params.\n";
				}
			} else {
				die __PACKAGE__."#execute, ARG[$param] was not a scalar nor ARRAY Ref.\n";
			}
		}

		if($sql =~ m/\?\?/) {
			die __PACKAGE__."#execute, parameters are too few. `??' still remains.\n";
		}
	} else {
		@params = @_;

		# この中にARRAY Refが入っていてはならない。
		if(grep {ref eq 'ARRAY'} @params) {
			die __PACKAGE__."#execute, use `??' instead of `?' if you want to use ARRAY Ref as a bind parameter.\n";
		}
	}

	# executeを行うDBセットを探す
	my $dbh = undef;
	if(defined($dbset)) {
		#DBセットが明示的に指定された
		$dbh = $this->{dbh}{$dbset};
		if(!$dbh) {
			die __PACKAGE__."#execute, dbset error. cannot set [$dbset].\n";
		}
	} else {
		$dbh = $this->{trans_dbh};
		$dbh = $this->{locked_dbh} if(!$dbh);
		$dbh = $this->{dbh}{$this->_getDbSetName} if(!$dbh);
	}

	my $sth = TL::DB::STH->new(
		$this,
		$dbh,
		$dbh->getDbh->prepare($sql)
	);

	# 全てのパラメータをbind_paramする。
	for(my $i = 0; $i < @params; $i++) {
		my $p = $params[$i];

		if(!ref($p)) {
			$sth->{sth}->bind_param($i + 1, $p);
		} elsif(ref($p) eq 'ARRAY') {
			if(@$p != 2 || ref($p->[1]) ne 'SCALAR') {
				die __PACKAGE__."#execute, attempted to bind an invalid array: [".join(', ', @$p)."]\n";
			}

			my $type = ${$p->[1]};
			my $typeconst = $this->{types_symtable}{$type};
			if(!$typeconst) {
				die __PACKAGE__."#execute, invalid sql type: [$type]\n";
			}
			$p->[1] = *{$typeconst}{CODE}->();

			$sth->{sth}->bind_param($i + 1, @$p);
		} else {
			my $argno = $i + 2;
			die __PACKAGE__."#execute, ARG[$argno] was bad Ref. [$p]\n";
		}
	}

	$sql = $this->__nameQuery($sql, $dbh);
	$sql_backup = $this->__nameQuery($sql_backup, $dbh);

	my $begintime = [Time::HiRes::gettimeofday()];

	while(1) {
		eval {
			local $SIG{__DIE__} = 'DEFAULT';

			$sth->{ret} = $sth->{sth}->execute;
		};
		if($@) {
			my $elapsed = Time::HiRes::tv_interval($begintime);
			$TL->getDebug->_dbLog(
				group   => $this->{group},
				set     => $dbh->getSetName,
				db      => $dbh->getGroup,
				id      => $sth->{id},
				query   => $sql_backup . " /* ERROR: $@ */",
				params  => \@_,
				elapsed => $elapsed,
				names   => $sth->nameArray,
				error   => 1,
			);

			die $@;
		} else {
			# dieしなかったならループ終了
			last;
		}
	}

	my $elapsed = Time::HiRes::tv_interval($begintime);
	$TL->getDebug->_dbLog(
		group   => $this->{group},
		set     => $dbh->getSetName,
		db      => $dbh->getGroup,
		id      => $sth->{id},
		query   => $sql_backup,
		params  => \@_,
		elapsed => $elapsed,
		names   => $sth->nameArray,
	);

	$sth;
}

sub selectAllHash {
	my $this = shift;
	my $sth = $this->execute(@_);

	my $result = [];
	while(my $data = $sth->fetchHash) {
		push @$result, { %$data };
	}
	$result;
}

sub selectAllArray {
	my $this = shift;
	my $sth = $this->execute(@_);

	my $result = [];
	while (my $data = $sth->fetchArray) {
		push @$result, [ @$data ];
	}
	$result;
}

sub selectRowHash {
	my $this = shift;
	my $sth = $this->execute(@_);
	
	my $data = $sth->fetchHash();
	$data = $data ? {%$data} : undef;
	$sth->finish();
	
	$data;
}

sub selectRowArray {
	my $this = shift;
	my $sth = $this->execute(@_);
	
	
	my $data = $sth->fetchArray();
	$data = $data ? [@$data] : undef;
	$sth->finish();
	
	$data;
}

sub lock {
	my $this = shift;
	my $opts = { @_ };

	my @tables;			# [name, 'WRITE' or 'READ']
	local *add = sub {
		my $type = shift;
		if(defined(my $table = $opts->{$type})) {
			if(!ref($table)) {
				push @tables, [$table, uc $type];
			} elsif (ref($table) eq 'ARRAY') {
				push @tables, map {
					if(!defined) {
						die __PACKAGE__."#lock, $type => [...] contains an undef.\n";
					} elsif(ref) {
						die __PACKAGE__."#lock, $type => [...] contains a Ref. [$_]\n";
					}

					[$_, uc $type];
				} @$table;
			} else {
				die __PACKAGE__."#lock, ARG[$type] is a bad Ref. [$table]\n";
			}
		}
	};
	add('read');
	add('write');

	if(!@tables) {
		die __PACKAGE__."#lock, no tables are being locked. Specify at least one table.\n";
	}

	my $sql = 'LOCK TABLES '.join(
		', ',
		map {
			my $table = $_->[0];
			my $type  = $_->[1];

			sprintf '%s %s',
				$this->symquote($table, $opts->{set}),
				$type;
		} @tables);

	my $set = $this->_getDbSetName($opts->{set});

	if(my $locked = $this->{locked_dbh}) {
		my $locked_set = $locked->getSetName;
		if($locked_set ne $set) {
			die __PACKAGE__."#lock, attempted to lock DB Set [$set] but ".
			"another DB Set [$locked_set] were locked. Unlock old one before lock new one.\n";
		} else {
			die __PACKAGE__."#lock, already some tables are locked. Unlock it first before lock another tables.\n";
		}
	}

	my $dbh = $this->{dbh}{$set};

	$sql = $this->__nameQuery($sql, $dbh);

	my $begintime = [Time::HiRes::gettimeofday()];

	$dbh->{dbh}->do($sql);
	$dbh->{locked} = 1;

	my $elapsed = Time::HiRes::tv_interval($begintime);
	$TL->getDebug->_dbLog(
		group   => $this->{group},
		set     => $dbh->getSetName,
		db      => $dbh->getGroup,
		id      => -1,
		query   => $sql,
		params  => [],
		elapsed => $elapsed,
	);

	$this->{locked_dbh} = $dbh;
	$this;
}

sub unlock {
	my $this = shift;

	my $dbh = $this->{locked_dbh};
	if(!defined($dbh)) {
		die __PACKAGE__."#unlock, no tables are locked.\n";
	}

	my $sql = $this->__nameQuery('UNLOCK TABLES', $dbh);
	my $begintime = [Time::HiRes::gettimeofday()];

	$dbh->{dbh}->do('UNLOCK TABLES');
	$dbh->{locked} = undef;

	my $elapsed = Time::HiRes::tv_interval($begintime);
	$TL->getDebug->_dbLog(
		group   => $this->{group},
		set     => $dbh->getSetName,
		db      => $dbh->getGroup,
		id      => -1,
		query   => $sql,
		params  => [],
		elapsed => $elapsed,
	);

	$this->{locked_dbh} = undef;
	$this;
}

sub setBufferSize {
	my $this = shift;
	my $kib = shift;

	if(ref($kib)) {
		die __PACKAGE__."#setBufferSize, ARG[1] was Ref.\n";
	}

	$this->{bufsize} = defined $kib ? $kib * 1024 : undef;
	$this;
}

sub symquote {
	my $this = shift;
	my $str = shift;

	if(!defined($str)) {
		die __PACKAGE__."#symquote, ARG[1] was undef.\n";
	} elsif(ref($str)) {
		die __PACKAGE__."#symquote, ARG[1] was Ref. [$str]\n";
	} elsif($str =~ m/[\'\"\`]/) {
		die __PACKAGE__."#symquote, ARG[1] contains a quote character. [$str]\n";
	}

	if($this->getType eq 'mysql') {
		qq[`$str`];
	} else {
		qq["$str"];
	}
}

sub getType {
	my $this = shift;

	$this->{type};
}

sub getDbh {
	my $this = shift;
	my $setname = shift;

	my $set = $this->_getDbSetName($setname);
	$this->{dbh}{$set}->getDbh;
}

sub _getDbSetName {
	my $this = shift;
	my $setname = shift;

	if(ref($setname)) {
		die __PACKAGE__."#_getDbSetName, ARG[1] was a Ref. [$setname]\n";
	}

	my $set;
	if(!defined($setname) || !length($setname)) {
		if($this->{default_set}) {
			$set = $this->{default_set};
		} else {
			die __PACKAGE__."#_getDbSetName, default DB set has not been set.".
				" Therefore we can't omit the name of one.\n";
		}
	} else {
		if($this->{dbh}{$setname}) {
			$set = $setname;
		} else {
			die __PACKAGE__."#_getDbSetName, DB set [$setname] was not defined. Please check the INI file.\n";
		}
	}

	$set;
}

sub _connect {
	# クラスメソッド。TL#startCgi，TL#errorTrapのみが呼ぶ。
	my $class = shift;
	my $groups = shift;

	foreach my $group (@$groups) {
		if (!defined($group)) {
			die "TL#startCgi, -DB had an unref value.\n";
		} elsif(ref($group)) {
			die "TL#startCgi, -DB had a Ref.\n";
		}

		$INSTANCES->{$group} = $class->_new($group)->connect;
	}

	# preRequest, postRequest, term をフックする
	$TL->setHook(
		'preRequest',
		_PRE_REQUEST_HOOK_PRIORITY,
		\&__preRequest,
	);

	$TL->setHook(
		'postRequest',
		_POST_REQUEST_HOOK_PRIORITY,
		\&__postRequest,
	);

	$TL->setHook(
		'term',
		_TERM_HOOK_PRIORITY,
		\&__term,
	);

	undef;
}

sub _new {
	my $class = shift;
	my $group = shift;

	my $this = bless {} => $class;
	$this->{group} = $group;
	$this->{namequery} = $TL->INI->get($group => 'namequery');
	$this->{type} = $TL->INI->get($group => 'type');

	$this->{bufsize} = undef; # 正の値でなければ無制限
	$this->{types_symtable} = \%TL::DB::SQL_TYPES::;

	$this->{dbh} = {};    # {DBセット名 => TL::DB::Dbh}
	$this->{dbname} = {}; # {DBコネクション名 => TL::DB::Dbh}

	$this->{default_set} = $TL->INI->get($group => 'defaultset', undef); # デフォルトのセット名

	$this->{locked_dbh} = undef; # TL::DB::Dbh
	$this->{trans_dbh} = undef; # TL::DB::Dbh

	do {
		local $SIG{__DIE__} = 'DEFAULT';
		eval q{
			package TL::DB::SQL_TYPES;
			use DBI qw(:sql_types);
		};
	};
	if($@) {
		die $@;
	}

	# ここでセット定義を読む
	foreach my $setname ($TL->INI->getKeys($group)) {
		$setname =~ m/^[a-z]+$/ and next; # 予約済

		my @db = split /\s*,\s*/, $TL->INI->get($group => $setname);
		if (!scalar(@db)) {
			# ゼロ個のDBから構成されるDBセットを作ってはならない。
			die __PACKAGE__."#new, DB Set [$setname] has no DBs.\n";
		}

		my $dbname = $db[$$ % scalar(@db)];
		if(!$this->{dbname}{$dbname}) {
			$this->{dbname}{$dbname} = TL::DB::Dbh->new($setname, $dbname);
		}
		$this->{dbh}{$setname} = $this->{dbname}{$dbname};
	}

	$this;
}

sub __nameQuery {
	my $this = shift;
	my $query = shift;
	my $dbh = shift;

	if(!$this->{namequery}) {
		return $query;
	}

	# スタックを辿り、最初に現れたTL::DB以外のパッケージが作ったフレームを見て、
	# ファイル名と行番号を得る。
	for(my $i = 0;; $i++) {
		my ($pkg, $fname, $lineno) = caller $i;
		if($pkg !~ m/^TL::DB/) {
			$fname =~ m!([^/]+)$!;
			$fname = $1;

			my $comment = sprintf '/* %s:%d [%s.%s.%s] */',
			$fname, $lineno, $this->{group}, $dbh->getSetName, $dbh->getGroup;

			$query =~ s/^(\s*\w+)/$1 $comment/;
			return $query;
		}
	}

	$query;
}

sub __preRequest {
	# $INSTANCESの中から、接続が確立していないものを接続する。
	foreach my $db (values %$INSTANCES) {
		$db->connect;
	}
}

sub __term {
	# $INSTANCESの接続を切断する。
	foreach my $db (values %$INSTANCES) {
		$db->disconnect;
	}
	undef $INSTANCES;
}

sub __postRequest {
	# $INSTANCESの中から、lockedのままになっているものに対して
	# UNLOCK TABLESを実行する。
	# また、トランザクションが済んでいないものについてはrollbackする。

	# 更にDBセットのデフォルト値をIniの物にする

	foreach my $db (values %$INSTANCES) {
		if(my $dbh = $db->{locked_dbh}) {
			$db->unlock;

			my $setname = $dbh->getSetName;
			$TL->log(
				__PACKAGE__,
				"DB [$db->{group}] (DB Set [$setname]) has been left locked after the last request.".
				" TL::DB unlocked it automatically for safe."
			);
		}
		if(my $dbh = $db->{trans_dbh}) {
			$db->rollback;

			my $setname = $dbh->getSetName;
			$TL->log(
				__PACKAGE__,
				"DB [$db->{group}] (DB Set [$setname]) has been left in transaction after the last request.".
				" TL::DB rollbacked it automatically for safe."
			);
		}

		$db->setDefaultSet($TL->INI->get($db->{group} => 'defaultset', undef));
	}
}


package TL::DB::Dbh;
use TL;

sub new {
	my $class = shift;
	my $setname = shift;
	my $dbname = shift;
	my $this = bless {} => $class;

	$this->{setname} = $setname;
	$this->{inigroup} = $dbname;
	$this->{dbh} = undef; # DBI-dbh

	$this;
}

sub getSetName {
	my $this = shift;

	$this->{setname};
}

sub getGroup {
	my $this = shift;

	$this->{inigroup};
}

sub getDbh {
	my $this = shift;

	$this->{dbh};
}

sub ping {
	my $this = shift;

	$this->{dbh} and $this->{dbh}->ping;
}

sub connect {
	my $this = shift;
	my $type = shift;

	$type or die __PACKAGE__."#connect, type is not set.\n";
	if($type eq 'mysql') {
		my $opts = {
			dbname => $TL->INI->get($this->{inigroup} => 'dbname'),
		};
		$opts->{dbname} or die __PACKAGE__."#connect, dbname is not set.\n";

		my $host = $TL->INI->get($this->{inigroup} => 'host');
		if(defined($host)) {
			$opts->{host} = $host;
		}

		my $port = $TL->INI->get($this->{inigroup} => 'port');
		if(defined($port)) {
			$opts->{port} = $port;
		}

		$this->{dbh} = DBI->connect(
			'dbi:mysql:' . join(';', map { "$_=$opts->{$_}" } keys %$opts),
			$TL->INI->get($this->{inigroup} => 'user'),
			$TL->INI->get($this->{inigroup} => 'password'), {
			AutoCommit => 1,
			PrintError => 0,
			RaiseError => 1,
		});
	} elsif($type eq 'pgsql') {
		my $opts = {
			dbname => $TL->INI->get($this->{inigroup} => 'dbname'),
		};
		$opts->{dbname} or die __PACKAGE__."#connect, dbname is not set.\n";

		my $host = $TL->INI->get($this->{inigroup} => 'host');
		if(defined($host)) {
			$opts->{host} = $host;
		}

		my $port = $TL->INI->get($this->{inigroup} => 'port');
		if(defined($port)) {
			$opts->{port} = $port;
		}

		$this->{dbh} = DBI->connect(
			'dbi:Pg:' . join(';', map { "$_=$opts->{$_}" } keys %$opts),
			$TL->INI->get($this->{inigroup} => 'user'),
			$TL->INI->get($this->{inigroup} => 'password'), {
			AutoCommit => 1,
			PrintError => 0,
			RaiseError => 1,
		});
	} elsif($type eq 'oracle') {
		$ENV{ORACLE_SID} = $TL->INI->get($this->{inigroup} => 'sid');
		$ENV{ORACLE_SID} or die __PACKAGE__."#connect, sid is not set.\n";
		$ENV{ORACLE_HOME} = $TL->INI->get($this->{inigroup} => 'home');
		$ENV{ORACLE_HOME} or die __PACKAGE__."#connect, home is not set.\n";
		$ENV{ORACLE_TERM} = 'vt100';
		$ENV{PATH} = $ENV{PATH} . ':' . $ENV{ORACLE_HOME} . '/bin';
		$ENV{LD_LIBRARY_PATH} = $ENV{LD_LIBRARY_PATH} . ':'
			. $ENV{ORACLE_HOME} . '/lib';
		$ENV{ORA_NLS33} = $ENV{ORACLE_HOME} . '/ocommon/nls/admin/data';
		$ENV{NLS_LANG} = 'JAPANESE_JAPAN.UTF8';

		$TL->INI->get($this->{inigroup} => 'user') or die __PACKAGE__."#connect, user is not set.\n";
		$TL->INI->get($this->{inigroup} => 'password') or die __PACKAGE__."#connect, password is not set.\n";
		my $option = $TL->INI->get($this->{inigroup} => 'user') . '/' . $TL->INI->get($this->{inigroup} => 'password');
		my $host = $TL->INI->get($this->{inigroup} => 'host');
		if(defined($host)) {
			$option .= '@' . $host;
		}

		$this->{dbh} = DBI->connect(
			'dbi:Oracle:',
			$option,
			'', {
			AutoCommit => 1,
			PrintError => 0,
			RaiseError => 1,
		});
	} elsif($type eq 'interbase') {
		my $opts = {
			dbname => $TL->INI->get($this->{inigroup} => 'dbname'),
			ib_charset => 'UNICODE_FSS',
		};
		$opts->{dbname} or die __PACKAGE__."#connect, dbname is not set.\n";

		my $host = $TL->INI->get($this->{inigroup} => 'host');
		if(defined($host)) {
			$opts->{host} = $host;
		}

		my $port = $TL->INI->get($this->{inigroup} => 'port');
		if(defined($port)) {
			$opts->{port} = $port;
		}

		$this->{dbh} = DBI->connect(
			'dbi:InterBase:' . join(';', map { "$_=$opts->{$_}" } keys %$opts),
			$TL->INI->get($this->{inigroup} => 'user'),
			$TL->INI->get($this->{inigroup} => 'password'), {
			AutoCommit => 1,
			PrintError => 0,
			RaiseError => 1,
		});
	} else {
		die __PACKAGE__."#connect, DB type [$type] is not supported.\n";
	}

	if(!$this->{dbh}) {
		die __PACKAGE__."#connect, DBI->connect returned undef.\n";
	}

	$this;
}

sub disconnect {
	my $this = shift;

	$this->{dbh} and $this->{dbh}->disconnect;
	$this;
}

sub begin {
	my $this = shift;

	$this->{dbh}->begin_work;
}

sub rollback {
	my $this = shift;

	$this->{dbh}->rollback;
}

sub commit {
	my $this = shift;

	$this->{dbh}->commit;
}


package TL::DB::STH;
use TL;
our $STH_ID = 0;

1;

sub new {
	my $class = shift;
	my $db = shift;
	my $dbh = shift;
	my $sth = shift;
	my $this = bless {} => $class;

	$this->{db_center} = $db; # TL::DB
	$this->{dbh} = $dbh; # TL::DB::DBH
	$this->{sth} = $sth; # native sth
	$this->{ret} = undef; # last return value
	$this->{id} = $STH_ID++;

	$this;
}

sub fetchHash {
	my $this = shift;
	my $hash = $this->{sth}->fetchrow_hashref;

	if($hash) {
		$TL->getDebug->_dbLogData(
			group   => $this->{group},
			set     => $this->{set}{name},
			db      => $this->{dbh}{inigroup},
			id      => $this->{id},
			data    => $hash,
		);
	}


	if(my $lim = $this->{db_center}{bufsize}) {
		my $size = 0;
		foreach(values %$hash) {
			$size += length;
		}

		if($size > $lim) {
			die __PACKAGE__."#fetchHash, buffer size exceeded: size [$size] / limit [$lim]\n";
		}
	}

	$hash;
}

sub fetchArray {
	my $this = shift;
	my $array = $this->{sth}->fetchrow_arrayref;

	if($array) {
		$TL->getDebug->_dbLogData(
			group   => $this->{group},
			set     => $this->{set}{name},
			db      => $this->{dbh}{inigroup},
			id      => $this->{id},
			data    => $array,
		);
	}

	if(my $lim = $this->{db_center}{bufsize}) {
		my $size = 0;
		foreach(@$array) {
			$size += length;
		}

		if($size > $lim) {
			die __PACKAGE__."#fetchArray, buffer size exceeded: size [$size] / limit [$lim]\n";
		}
	}

	$array;
}

sub ret {
	my $this = shift;
	$this->{ret};
}

sub rows {
	my $this = shift;
	$this->{sth}->rows;
}

sub finish {
	my $this = shift;
	$this->{sth}->finish;
}

sub nameArray {
	my $this = shift;
	$this->{sth}{NAME_lc};
}

sub nameHash {
	my $this = shift;
	$this->{sth}{NAME_lc_hash};
}

__END__

=encoding utf-8

=head1 NAME

TL::DB - DBIのラッパ

=head1 SYNOPSIS

  $TL->startCgi(
      -DB      => 'DB',
      -main        => \&main,
  );

  sub main {
    my $DB = $TL->getDB('DB');

    $DB->setDefaultSet('R_Trans');
    $DB->begin;

    my $sth = $DB->execute(q{SELECT a, b FROM foo WHERE a = ?}, 999);
    while (my $hash = $sth->fetchHash) {
        print $hash->{a};
    }
    $DB->commit;

    $DB->begin('W_Trans');
    $DB->execute(q{UPDATE counter SET counter = counter + 1 WHERE id = ?}, 1);
    $DB->commit;
  }

=head1 DESCRIPTION

=over 4

=item 接続/切断は自動で行われる。

手動で接続/切断する場合は、connect/disconnectを使う。

=item 実行クエリの処理時間・実行計画・結果を記録するデバッグモード。

=item prepare/executeを分けない。fetchは分ける。

=item 拡張プレースホルダ機能

  $db->execute(q{select * from a where mode in (??)}, ['a', 'b'])

と記述すると、

  $db->execute(q{select * from a where mode in (?, ?)}, 'a', 'b')

のように解釈される。

=item プレースホルダの値渡しの際に型指定が可能

  $db->execute(q{select * from a limit ??}, ['a', \'SQL_INTEGER'])

=item リクエスト処理完了後のトランザクション未完了やunlock未完了を自動検出

=item DBグループ・DBセット・DBコネクション

TL::DBでは、レプリケーションを利用してロードバランスすることを支援するため、
１つのDBグループの中に、複数のDBセットを定義することが可能となっている。
DBセットの中には、複数のDBコネクションを定義できる。

更新用DBセット、参照用DBセット、などの形で定義しておき、プログラム中で
トランザクション単位でどのDBセットを使用するか指定することで、
更新用クエリはマスタDB、参照用クエリはスレーブDB、といった
使い分けをすることが可能となる。

DBセットには複数のDBコネクションを定義でき、複数定義した場合は
プロセス単位でプロセスIDを元に1つのコネクションが選択される。
（プロセスIDを定義数で割り、その余りを使用して決定する。）

同じDBグループの中の複数のDBセットで同じDBコネクション名が使用された場合は、
実際にDBに接続されるコネクション数は1つとなる。
このため、縮退運転時に参照用DBセットのDBコネクションを更新用の
ものに差し替えたり、予め将来を想定して多くのDBセットに分散
させておくことが可能となっている。

DBセットの名称はSET_XXXX(XXXXは任意の文字列)でなければならない。 
DBコネクションの名称はCNT_XXXX(XXXXは任意の文字列)でなければならない。

=back


=head2 拡張プレースホルダ詳細

L</"execute"> に渡されるSQL文には、通常のプレースホルダの他に、
拡張プレースホルダ "??" を埋め込む事が出来る。
拡張プレースホルダの置かれた場所には、パラメータとして通常のスカラー値でなく、
配列へのリファレンスを与えなければならない。配列が複数の値を持っている場合には、
それらが通常のプレースホルダをカンマで繋げたものに展開される。

例: 以下の二文は等価

  $DB->execute(
      q{SELECT * FROM a WHERE a IN (??) AND b = ?},
      ['AAA', 'BBB', 'CCC'], 800);
  $DB->execute(
      q{SELECT * FROM a WHERE a IN (?, ?, ?) AND b = ?},
      'AAA', 'BBB', 'CCC', 800);

パラメータとしての配列の最後の項目が文字列へのリファレンスである時、その文字列は
SQL型名として扱われる。配列が複数の値を持つ時には、その全ての要素に対して
型指定が適用される。型名はDBI.pmで定義される。

例:

  $DB->execute(q{SELECT * FROM a LIMIT ??}, [20, \'SQL_INTEGER']);
  ==> SELECT * FROM a LIMIT 20
  
  $DB->execute(q{SELECT * FROM a LIMIT ??}, [20, 5, \'SQL_INTEGER']);
  ==> SELECT * FROM a LIMIT 20, 5

配列内の要素を更に2要素の配列とし、二番目の要素を文字列へのリファレンスと
する事で、要素の型を個別に指定出来る。

例:

  $DB->execute(
      q{SELECT * FROM a WHERE a IN (??) AND b = ?},
      [[100, \'SQL_INTEGER'], 'foo', \'SQL_VARCHAR'], 800);
  ==> SELECT * FROM a WHERE a IN (100, 'foo') AND b = '800'


=head2 METHODS

=head3 C<TL::DB> メソッド

=over 4

=item C<< $TL->getDB >>

   $DB = $TL->getDB
   $DB = $TL->getDB($inigroup)

TL::DB オブジェクトを取得。
引数にはIniで設定したグループ名を渡す。
引数省略時は 'DB' グループが使用される。

L<< $TL->startCgi|TL/"startCgi" >> /  L<< $TL->errorTrap|TL/"errorTrap" >> の関数内でDBオブジェクトを取得する場合に使用する。

=item C<< $TL->newDB >>

   $DB = $TL->newDB
   $DB = $TL->newDB($inigroup)

新しく TL::DB オブジェクト作成。
引数にはIniで設定したグループ名を渡す。
引数省略時は 'DB' グループが使用される。

動的にコネクションを作成したい場合などに使用する。
この方法で TL::DB オブジェクトを取得した場合、L<"connect"> / L<"disconnect"> を呼び出し、接続の制御を行う必要がある。

=item C<< connect >>

DBに接続する。

L<< $TL->startCgi|TL/"startCgi" >> /  L<< $TL->errorTrap|TL/"errorTrap" >> の関数内でDBオブジェクトを取得する場合には自動的に接続が管理されるため、このメソッドを呼び出してはならない。

L<< $TL->newDB|"$TL->newDB" >> で作成した TL::DB オブジェクトに関しては、このメソッドを呼び出し、DBへ接続する必要がある。

connect時には、AutoCommit 及び RaiseError オプションは 1 が指定され、PrintError オプションは 0 が指定される。

=item C<< disconnect >>

DBから切断する。

L<< $TL->startCgi|TL/"startCgi" >> /  L<< $TL->errorTrap|TL/"errorTrap" >> の関数内でDBオブジェクトを取得する場合には自動的に接続が管理されるため、このメソッドを呼び出してはならない。

L<< $TL->newDB|"$TL->newDB" >> で作成した TL::DB オブジェクトに関しては、このメソッドを呼び出し、DBへの接続を切断する必要がある。

=item C<< begin >>

  $DB->begin
  $DB->begin('SET_W_Trans')

指定されたDBセット名でトランザクションを開始する。トランザクション名
(DBセット名) はiniで定義されていなければならない。
名前を省略した場合は、デフォルトのDBセットが使われるが、
setDefaultSetによってデフォルトが選ばれていない場合にはエラーとなる。

CGIの中でトランザクションを開始し、終了せずにMain関数を抜けた場合は、自動的に
rollbackされる。

トランザクション実行中にこのメソッドを呼んだ場合には、エラーとなる。
1度に開始出来るトランザクションは、1つのDBグループにつき1つだけとなる。

=item C<< rollback >>

  $DB->rollback

現在実行中のトランザクションを取り消す。

=item C<< commit >>

  $DB->commit

現在実行中のトランザクションを確定する。

=item C<< setDefaultSet >>

  $DB->setDefaultSet('SET_W_Trans')

デフォルトのDBセットを選択する。ここで設定されたDBセットは、引数無しのbegin()
や、beginせずに行ったexecuteの際に使われる。このメソッドは
L<Main関数|TL/"Main関数"> の先頭で呼ばれる事を想定している。

=item C<< execute >>

  $DB->execute($sql, $param...)
  $DB->execute(\'SET_W_Trans' => $sql, $param...)

SELECT/UPDATE/DELETEなどのSQL文を実行する。
第1引数にSQL、第2引数以降にプレースホルダの引数を渡す。
ただし、第1引数にリファレンスでDBセットを渡すことにより、
トランザクション外での実行時にDBセットを指定することが可能。

第2引数以降の引数では、拡張プレースホルダが使用できる。
L</"拡張プレースホルダ詳細"> を参照。

既にトランザクションが実行されていれば、そのトランザクションの
DBセットでSQLが実行される。

トランザクションが開始されておらず、かつ L</"lock"> により
テーブルがロックされていれば、ロックをかけているDBセットでSQLが実行される。

いずれの場合でもない場合は、L</"setDefaultSet"> で指定された
トランザクションが使用される。
L</"setDefaultSet"> による設定がされていない場合は、エラーとなる。

このメソッドを使用して、LOCK/UNLOCK/BEGIN/COMMITといったSQL文を
実行してはならない。実行しようとした場合はエラーになる。
代わりに専用のメソッドを使用する事。

=item C<< selectAllHash >>

  $DB->selectAllHash($sql, $param...)
  $DB->selectAllHash(\'SET_W_Trans' => $sql, $param...)

SELECT結果をハッシュの配列へのリファレンスで返す。
データがない場合は [] が返る。

  my $arrayofhash = $DB->selectAllHash($sql, $param...);
  foreach my $hash (@$arrayofhash){
     $TL->log(DBDATA => "name of id $hash->{id} is $hash->{name}");
  }

=item C<< selectAllArray >>

  $DB->selectAllArray($sql, $param...)
  $DB->selectAllArray(\'SET_W_Trans' => $sql, $param...)

SELECT結果を配列の配列へのリファレンスで返す。
データがない場合は [] が返る。

  my $arrayofarray = $DB->selectAllArray($sql, $param...);
  foreach my $array (@$arrayofarray){
     $TL->log(DBDATA => $array->[0]);
  }

=item C<< selectRowHash >>

  $DB->selectRowHash($sql, $param...)
  $DB->selectRowHash(\'SET_W_Trans' => $sql, $param...)

SELECT結果の最初の１行をハッシュへのリファレンスで返す。
実行後、内部でfinishする。
データがない場合は undef が返る。

  my $hash = $DB->selectRowHash($sql, $param...);
  $TL->log(DBDATA => "name of id $hash->{id} is $hash->{name}");

=item C<< selectRowArray >>

  $DB->selectRowArray($sql, $param...)
  $DB->selectRowArray(\'SET_W_Trans' => $sql, $param...)

SELECT結果の最初の１行を配列へのリファレンスで返す。
実行後、内部でfinishする。
データがない場合は undef が返る。

  my $array = $DB->selectRowArray($sql, $param...);
  $TL->log(DBDATA => $array->[0]);

=item C<< lock >>

  $DB->lock(set => 'SET_W_Trans', read => ['A', 'B'], write => 'C')

指定されたDBセットに対してLOCK TABLESを実行する。setが省略された場合はデフォルト
のDBセットが選ばれる。CGIの中でロックした場合は、 L<Main関数|TL/"Main関数">
を抜けた時点で自動的にunlockされる。

ロック実行中にこのメソッドを呼んだ場合には、エラーとなる。
1度に開始出来るロックは、1つのDBグループにつき1つだけとなる。

=item C<< unlock >>

  $DB->unlock

UNLOCK TABLES を実行する。
ロックがかかっていない場合はエラーとなる。

=item C<< setBufferSize >>

  $DB->setBufferSize($kbytes)

バッファサイズをKB単位でセットする。行を１行読み込んだ結果
このサイズを上回る場合、C<< die >>する。
C<< 0 >> または C<< undef >> をセットすると、制限が解除される。

=item C<< symquote >>

  $DB->symquote($sym)

文字列を識別子としてクォートする。

mysqlの場合は C<< `a b c` >> となり、それ以外の場合は C<< "a b c" >> となる。

=item getType

  $DB->getType;

DBのタイプを返す。C<< (mysql, pgsql, ...) >>

=item getDbh

  $dbh = $DB->getDbh
  $dbh = $DB->getDbh('SET_W_Trans')

DBセット内のDBハンドルを返す。
返されるオブジェクトは L<DBI> ネイティブのdbhである。

ネイティブのDBハンドルを使用してクエリを発行した場合、デバッグ機能（プロファイリング等）の機能は使用できません。
また、トランザクションやロック状態の管理もフレームワークで行えなくなるため、注意して使用する必要があります。

=back

=head3 C<TL::DB::STH> メソッド

=over 4

=item C<< fetchHash >>

  $sth->fetchHash

ハッシュへのリファレンスで１行取り出す。

=item C<< fetchArray >>

  $sth->fetchArray

配列へのリファレンスで１行取り出す。

=item C<< ret >>

  $sth->ret

最後に実行した execute の戻り値を返す。

=item C<< rows >>

  $sth->rows

DBIと同様。

=item C<< finish >>

  $sth->finish

DBIと同様。

=item C<< nameArray >>

  $sth->nameArray

C<< $sth->{NAME_lc} >> を返す。

=item C<< nameHash >>

  $sth->nameHash

C<< $sth->{NAME_lc_hash} >> を返す。

=back


=head2 Ini パラメータ

=head3 DBセット・DBコネクション

DBグループのパラメータのうち、半角小文字英数字のみで構成された
パラメータは予約済みで、DBグループの動作設定に使用する。
DBセットは、予約済みではない名前であれば任意の名称が使用でき、
値としてDBコネクションのINIグループ名をカンマ区切りで指定する。

例:

  [DB]
  namequery=1
  type=mysql
  defaultset=SET_R_Trans
  SET_W_Trans=CNT_DBW1
  SET_R_Trans=CNT_DBR1,CNT_DBR2
  
  [CNT_DBW1]
  dbname=test
  user=daemon
  host=192.168.0.100
  
  [CNT_DBR1]
  dbname=test
  user=daemon
  host=192.168.0.110
  
  [CNT_DBR2]
  dbname=test
  user=daemon
  host=192.168.0.111

以下は特別なパラメータ:

=over 4

=item C<< namequery >>

  namequery = 1

これを1にすると、実行しようとしたクエリのコマンド名の直後に
C<< /* foo.pl:111 [DB.R_Transaction1.DBR1] */ >> のようなコメントを挿入する。
デフォルトは0。

=item C<< type >>

  type = mysql

DBの種類を選択する。
mysql, pgsql, oracleが使用可能。
必須項目。

=item C<< defaultset >>

  defaultset = SET_W_Trans

デフォルトのDBセットを設定する。
ここで設定されたDBセットは、引数無しのbegin()や、beginせずに行ったexecuteの際に使われる。

=back


=head3 DB定義

=over 4

=item C<< dbname >>

  dbname = test

DB名を設定する。

=item C<< host >>

  host = localhost

DBのアドレスを設定する。
デフォルトはlocalhost。

=item C<< user >>

  user = www

DBに接続する際のユーザー名を設定する。

=item C<< password >>

  password = PASS

DBに接続する際のパスワードを設定する。
省略可能。

=back


=head1 SEE ALSO

L<TL>

=head1 AUTHOR INFORMATION

=over 4

Copyright 2006 YMIRLINK Inc. All Rights Reserved.

This framework is free software; you can redistribute it and/or modify it under the same terms as Perl itself

このフレームワークはフリーソフトウェアです。あなたは Perl と同じライセンスの 元で再配布及び変更を行うことが出来ます。

Address bug reports and comments to: tl@tripletail.jp

HP : http://tripletail.jp/

=back

=cut
