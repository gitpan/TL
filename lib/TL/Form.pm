# -----------------------------------------------------------------------------
# TL::Form - フォーム情報
# -----------------------------------------------------------------------------
package TL::Form;


1;

sub _new {
	my $pkg = shift;
	my $this = bless {} => $pkg;

	$this->{form} = {}; # key => [value, ...]
	$this->{form_shared} = {}; # key => 1 / 配列が複数のFormのインスタンスで共有されているなら1

	$this->{filename} = {}; # key => filename
	$this->{filehandle} = {}; # key => ih
	$this->{fragment} = undef; # scalar

	if(@_ == 1) {
		my $url = shift;

		if(!defined($url)) {
			die "TL#newForm, ARG[1] was undef.\n";
		} elsif(ref($url)) {
			die "TL#newForm, ARG[1] was Ref.\n";
		}

		$this->setLink($url);
	} else {
		$this->set(@_);
	}

	$this;
}

sub _trace {
	my $this = shift;

	$this->{trace} = 1;

	$this;
}

sub const {
	my $this = shift;

	$this->{const} = 1;

	$this;
}

sub clone {
	# deep copyはせずに、キー単位でのcopy-on-writeを行う。
	my $this = shift;
	my $f = $TL->newForm;

	@{$f->{form}}{keys %{$this->{form}}} = values %{$this->{form}};
	@{$f->{form_shared}}{keys %{$this->{form}}} = (1) x keys %{$this->{form}};
	@{$this->{form_shared}}{keys %{$this->{form}}} = (1) x keys %{$this->{form}};

	@{$f->{filename}}{keys %{$this->{filename}}} = values %{$this->{filename}};
	@{$f->{filehandle}}{keys %{$this->{filehandle}}} = values %{$this->{filehandle}};
	
	$f->{fragment} = $this->{fragment};

	$f;
}

sub addForm {
	my $this = shift;
	my $form = shift;

	if(exists($this->{const})) {
		die "TL::Form#addForm, This instance is const object.\n";
	}

	if(ref($form) ne 'TL::Form') {
		die "TL::Form#addForm, ARG[1]: is not Form Class.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'addForm',
			form => $form,
		);
	}

	@{$this->{form}}{keys %{$form->{form}}} = values %{$form->{form}};
	@{$this->{form_shared}}{keys %{$form->{form}}} = (1) x keys %{$form->{form}};
	@{$f->{form_shared}}{keys %{$form->{form}}} = (1) x keys %{$form->{form}};

	@{$this->{filename}}{keys %{$form->{filename}}} = values %{$form->{filename}};
	@{$this->{filehandle}}{keys %{$form->{filehandle}}} = values %{$form->{filehandle}};
	
	if(defined $form->{fragment}) {
		$this->{fragment} = $form->{fragment};
	}

	$this;
}

sub getKeys {
	my $this = shift;

	keys %{$this->{form}};
}

sub get {
	my $this = shift;
	my $key = shift;
	my $joinstr = shift || ',';

	if(ref($key)) {
		die "TL::Form#get, ARG[1]: is Ref.\n";
	}
	if(ref($joinstr)) {
		die "TL::Form#get, ARG[2]: is Ref.\n";
	}

	if(!exists($this->{form}{$key})) {
		return undef;
	}

	join($joinstr, @{$this->{form}{$key}});
}

sub getValues {
	my $this = shift;
	my $key = shift;

	if(ref($key)) {
		die "TL::Form#getValues, ARG[1]: is Ref.\n";
	}

	if(!exists($this->{form}{$key})) {
		return ();
	}

	@{$this->{form}{$key}};
}

sub getSlice {
	my $this = shift;
	my @key = (@_);

	my @res;

	foreach my $key (@key) {
		if (ref($key)) {
			my $ref = ref($key);
			die "TL::Form#getSlice, ARG[]: include Ref. [$key/$ref]\n";
		}

		my @values = $this->getValues($key);
		if(scalar(@values) == 1) {
			push(@res, $key);
			push(@res, $values[0]);
		} elsif(scalar(@values) == 0) {
		} else {
			push(@res, $key);
			push(@res, \@values);
		}
	}

	@res;
}

sub getSliceValues {
	my $this = shift;
	my @key = (@_);

	my @res;

	foreach my $key (@key) {
		if(ref($key)) {
			my $ref = ref($key);
			die "TL::Form#getSliceValues, ARG[]: include Ref. [$key/$ref]\n";
		}

		my @values = $this->getValues($key);
		if(scalar(@values) == 1) {
			push(@res, $values[0]);
		} elsif(scalar(@values) == 0) {
			push(@res, undef);
		} else {
			push(@res, \@values);
		}
	}

	@res;
}

sub lookup {
	my $this = shift;
	my $key = shift;
	my $value = shift;

	if(ref($key)) {
		die "TL::Form#lookup, ARG[1]: is Ref.\n";
	}
	if(ref($value)) {
		die "TL::Form#lookup, ARG[2]: is Ref.\n";
	}

	if(!exists($this->{form}{$key})) {
		return undef;
	}

	my $found;
	for(my $i = 0; $i <= $#{$this->{form}{$key}}; $i++) {
		if($this->{form}{$key}[$i] eq $value) {
			$found = 1;
			last;
		}
	}

	if(!$found) {
		return undef;
	}

	1;
}

sub set {
	my $this = shift;

	if(exists($this->{const})) {
		die "TL::Form#set, This instance is const object.\n";
	}

	my $data;
	if(ref($_[0]) eq 'HASH') {
		$data = shift;
	} elsif(!ref($_[0])) {
		$data = { @_ };
	} else {
		my $ref = ref($_[0]);
		die "TL::Form#set, ARG[1]: is Wrong-Ref. [$ref]\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'set',
			data => $data,
		);
	}

	foreach my $key (keys %$data) {
		delete $this->{form}{$key};
		if(ref($data->{$key}) eq 'ARRAY') {
			$this->{form}{$key} = $data->{$key};
		} elsif(!ref($data->{$key})) {
			$this->{form}{$key}[0] = $data->{$key};
		} else {
			die "TL::Form#set, ARG[]: Data include Wrong-Ref. [$key/$ref]\n";
		}
	}

	$this;
}

sub add {
	my $this = shift;
	my $key = shift;
	my $value = shift;

	if(exists($this->{const})) {
		die "TL::Form#add, This instance is const object.\n";
	}

	if(ref($key)) {
		die "TL::Form#add, ARG[1]: is Ref.\n";
	}
	if(ref($value)) {
		die "TL::Form#add, ARG[2]: is Ref.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'add',
			key => $key,
			value => $value,
		);
	}

	if($this->{form_shared}{$key}) {
		# copy-on-write
		$this->{form}{$key} = [
			@{$this->{form}{$key}},
			$value,
		];

		# 以後はコピーしない
		delete $this->{form_shared}{$key};
	} else {
		push @{$this->{form}{$key}}, $value;
	}

	$this;
}

sub exists {
	my $this = shift;
	my $key = shift;

	if(ref($key)) {
		die "TL::Form#exists, ARG[1]: is Ref.\n";
	}

	if(exists($this->{form}{$key})) {
		return 1;
	}

	undef;
}

sub remove {
	my $this = shift;
	my $key = shift;
	my $value = shift;

	if(exists($this->{const})) {
		die "TL::Form#remove, This instance is const object.\n";
	}

	if(!defined($key)) {
		die "TL::Form#remove, ARG[1]: was undef.\n";
	} elsif(ref($key)) {
		die "TL::Form#remove, ARG[1]: was Ref.\n";
	}
	if(!defined($value)) {
		die "TL::Form#remove, ARG[2]: was undef.\n";
	} elsif(ref($value)) {
		die "TL::Form#remove, ARG[2]: was Ref.\n";
	}

	if(!exists($this->{form}{$key})) {
		die "TL::Form#remove, ARG[1]: Not exists key [$key]\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'remove',
			key => $key,
			value => $value,
		);
	}

	for(my $i = 0; $i <= $#{$this->{form}{$key}}; $i++) {
		if($this->{form}{$key}[$i] eq $value) {

			if(@{$this->{form}{$key}} == 1) {
				# これが最後の値
				delete $this->{form}{$key};
				delete $this->{form_shared}{$key};
			} else {
				if($this->{form_shared}{$key}) {
					# copy-on-write
					my @array = @{$this->{form}{$key}};
					splice @array, $i, 1;
					$this->{form}{$key} = \@array;

					# 以後はコピーしない
					delete $this->{form_shared}{$key};
				} else {
					splice @{$this->{form}{$key}}, $i, 1;
				}
			}

			last;
		}
	}

	$this;
}

sub delete {
	my $this = shift;
	my $key = shift;

	if(exists($this->{const})) {
		die "TL::Form#delete, This instance is const object.\n";
	}

	if(ref($key)) {
		die "TL::Form#delete, ARG[1]: is Ref.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'delete',
			key => $key,
		);
	}

	if(!exists($this->{form}{$key})) {
		return $this;
	}

	delete $this->{form}{$key};
	delete $this->{form_shared}{$key};

	$this;
}

sub getFile {
	my $this = shift;
	my $key = shift;

	if (ref $key) {
		die "TL::Form#getFile, ARG[1] was Ref.\n";
	}

	$this->{filehandle}{$key};
}

sub setFile {
	my $this = shift;
	my $key = shift;
	my $value = shift;

	if(exists($this->{const})) {
		die "TL::Form#setFile, This instance is const object.\n";
	}

	if(ref($key)) {
		die "TL::Form#setFile, ARG[1]: is Ref.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'setFile',
			key => $key,
			value => defined $value ? "$value" : '[undef]',
		);
	}
	
	if(!defined($value)) {
		delete $this->{filehandle}{$key};
	} elsif(!ref($value)) {
		die "TL::Form#setFile, ARG[2]: is not Ref.\n";
	} else {
		$this->{filehandle}{$key} = $value;
	}

	$this;
}

sub getFileKeys {
	my $this = shift;

	keys %{$this->{filehandle}};
}

sub getFileName {
	my $this = shift;
	my $key = shift;

	if(ref($key)) {
		die "TL::Form#getFileName, ARG[1]: is Ref.\n";
	}

	$this->{filename}{$key};
}

sub setFileName {
	my $this = shift;
	my $key = shift;
	my $value = shift;

	if(exists($this->{const})) {
		die "TL::Form#setFileName, This instance is const object.\n";
	}

	if(ref($key)) {
		die "TL::Form#setFileName, ARG[1]: is Ref.\n";
	}
	if(ref($value)) {
		die "TL::Form#setFileName, ARG[2]: is Ref.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'setFileName',
			key => $key,
			value => defined $value ? $value : '[undef]',
		);
	}

	if(defined($value)) {
		$this->{filename}{$key} = $value;
	} else {
		delete $this->{filename}{$key};
	}

	$this;
}

sub setLink {
	my $this = shift;
	my $url = shift;

	if($this->{const}) {
		die __PACKAGE__."#setLink, This instance is const object.\n";
	}

	if(!defined($url)) {
		die __PACKAGE__."#setLink, ARG[1] was undef.\n";
	}
	if(ref($url)) {
		die __PACKAGE__."#setLink, ARG[1] was Ref.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'setLink',
			value => $url,
		);
	}

	local($this->{trace}) = undef;
	foreach my $key ($this->getKeys) {
		$this->delete($key);
	}
	$this->addLink($url);

	$this;
}

sub addLink {
	my $this = shift;
	my $url = shift;

	if($this->{const}) {
		die __PACKAGE__."#addLink, This instance is const object.\n";
	}

	if(!defined($url)) {
		die __PACKAGE__."#addLink, ARG[1] was undef.\n";
	}
	if(ref($url)) {
		die __PACKAGE__."#addLink, ARG[1] was Ref.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'addLink',
			value => $url,
		);
	}

	local($this->{trace}) = undef;

	my ($form, $fragment) = $TL->_decodeFromURL($url);
	$this->addForm($form);
	$this->setFragment($fragment);

	$this;
}

sub setFragment {
	my $this = shift;
	my $fragment = shift;

	if($this->{const}) {
		die __PACKAGE__."#setFragment, This instance is const object.\n";
	}

	if(ref($fragment)) {
		die __PACKAGE__."#setFragment, ARG[1] was Ref.\n";
	}

	if($this->{trace}) {
		$TL->getDebug->_formLog(
			type => 'setFragment',
			value => $fragment
		);
	}

	$this->{fragment} = $fragment;

	$this;
}

sub getFragment {
	my $this = shift;

	$this->{fragment};
}

sub toLink {
	my $this = shift;
	my $base = shift;

	if(ref($base)) {
		die __PACKAGE__."#toLink, ARG[1] was Ref.\n";
	}

	if(!defined($base)) {
		my $uri = $ENV{'SCRIPT_NAME'}||'';
		$uri =~ s/\?.*$//;
		if($uri =~ m,/([^/]+)$,) {
			$base = $1;
		} else {
			$base = './';
		}
	}

	my $flag = 0;
	foreach my $key (sort $this->getKeys) {
		foreach my $value (sort $this->getValues($key)) {
			if($flag == 0) {
				$base .= '?';
				$flag = 1;
			} else {
				$base .= '&';
			}
			$base .= $TL->encodeURL($key) . '=' . $TL->encodeURL($value);
		}
	}
	if($flag == 0) {
		$base .= '?';
	} else {
		$base .= '&';
	}
	$base .= 'INT=1';

	if(defined($this->{fragment})) {
		$base .= '#' . $TL->encodeURL($this->{fragment});
	}

	$base;
}

sub toExtLink {
	my $this = shift;
	my $base = shift;
	my $code = shift;
	
	if(!defined($code)) {
		$code = 'UTF-8';
	}
	
	if(ref($base)) {
		die __PACKAGE__."#toExtLink, ARG[1] was Ref.\n";
	}

	if(!defined($base)) {
		my $uri = $ENV{'SCRIPT_NAME'}||'';
		$uri =~ s/\?.*$//;
		if($uri =~ m,/([^/]+)$,) {
			$base = $1;
		} else {
			$base = './';
		}
	}

	my $flag = 0;
	foreach my $key (sort $this->getKeys) {
		foreach my $value (sort $this->getValues($key)) {
			if($flag == 0) {
				$base .= '?';
				$flag = 1;
			} else {
				$base .= '&';
			}
			$base .= $TL->encodeURL($TL->charconv($key, 'UTF-8' => $code))
				. '=' . $TL->encodeURL($TL->charconv($value, 'UTF-8' => $code));
		}
	}

	if(defined($this->{fragment})) {
		$base .= '#' . $TL->encodeURL($TL->charconv($this->{fragment}, 'UTF-8' => $code));
	}

	$base;
}

sub haveSessionCheck {
	my $this = shift;
	my $sessiongroup = shift;
	my $issecure = shift;

	if(!defined($sessiongroup)) {
		die __PACKAGE__."#haveSessionCheck, ARG[1] was undef.\n";
	}
	my $session = $TL->getSession($sessiongroup);
	if(!defined($session)) {
		die __PACKAGE__."#haveSessionCheck, session group ($sessiongroup) was not found.\n";
	}
	my $csrfkey = $TL->INI->get($sessiongroup => 'csrfkey', undef);
	if(!defined($csrfkey)) {
		die __PACKAGE__."#haveSessionCheck, csrfkey was not set. set INI [$sessiongroup]..\n";
	}

	do {
		local $SIG{__DIE__} = 'DEFAULT';
		eval 'use Digest::HMAC_SHA1 qw(hmac_sha1_hex)';
	};
	if($@) {
		die __PACKAGE__."#haveSessionCheck, failed to load HMAC_SHA1.pm [$@]\n";
	}

	my ($key, $sid, $checkval) = $session->getSessionInfo($issecure);
	
	if(!defined($sid)) {
		return undef;
	}
	
	$key = 'C' . $key;

	if($this->get($key) eq hmac_sha1_hex(join('.', $sid, $checkval), $csrfkey)) {
		return 1;
	} else {
		return undef;
	}
}

sub _freeze {
	my $this = shift;

	$this->_h2s($this->{form});
}

sub _thaw {
	my $this = shift;
	my $frozen = shift;

	$this->{form} = $this->_s2h($frozen);
	$this;
}

# ハッシュ<->文字列

sub _h2s {
	my $this = shift;
	my $hash = shift;

	my $str = '';
	foreach my $key (keys %$hash) {
		next if(!defined($key));
		my $data;
		if(ref($hash->{$key}) eq 'HASH') {
			$data = $this->_h2s($hash->{$key});
		} elsif(ref($hash->{$key}) eq 'ARRAY') {
			$data = $this->_a2s($hash->{$key});
		} elsif(defined($hash->{$key})) {
			$data = unpack('H*', $hash->{$key});
		} else {
			$data = '';
		}
		$str .= 'h' . unpack('H*', $key) . 'r' . unpack('H*', $data);
	}

	return $str;

}

sub _s2h{
	my $this = shift;
	my $str = shift;

	my $hash = {};
	my @node = split(/h/, $str);
	shift(@node);
	foreach my $node (@node) {
		my ($key, $data) = split(/r/, $node, 2);
		$key = pack('H*', $key);
		$data = pack('H*', $data);
		if($data =~ m/^h/) {
			$data = $this->_s2h($data);
		} elsif($data =~ m/^y/) {
			$data = $this->_s2a($data);
		} elsif(defined($data)) {
			$data = pack('H*', $data);
		} else {
			$data = '';
		}
		$hash->{$key} = $data;
	}

	return $hash;

}

sub _a2s {
	my $this = shift;
	my $array = shift;

	my $str = '';
	foreach my $key (@$array) {
		next if(!defined($key));
		my $data;
		if(ref($key) eq 'HASH') {
			$data = $this->_h2s($key);
		} elsif(ref($key) eq 'ARRAY') {
			$data = $this->_a2s($key);
		} elsif(defined($key)) {
			$data = unpack('H*', $key);
		} else {
			$data = '';
		}
		$str .= 'y' . unpack('H*', $data);
	}

	$str;

}

sub _s2a {
	my $this = shift;
	my $str = shift;

	my $array = [];
	my @node = split(/y/, $str);
	shift(@node);
	foreach my $node (@node) {
		my $data = pack('H*', $node);
		if($data =~ m/^h/) {
			$data = $this->_s2h($data);
		} elsif($data =~ m/^y/) {
			$data = $this->_s2a($data);
		} elsif(defined($data)) {
			$data = pack('H*', $data);
		} else {
			$data = '';
		}
		push(@$array, $data);
	}

	$array;
}


__END__

=encoding utf-8

=head1 NAME

TL::Form - フォーム情報

=head1 SYNOPSIS

  my $form = $TL->newForm;
  $form->set(Command => 'DoDispList');
  
  $TL->location(
      $form->toLink('foo.cgi'));
  # Location: http://....../foo.cgi?Command=DoDispList

=head1 DESCRIPTION

CGIへのクエリ情報を保持するクラス。
一つのキーに対し、1つ以上の値を持つ。

=head2 METHODS

=over 4

=item C<< $TL->newForm >>

  $form = $TL->newForm
  $form = $TL->newForm(a => 1, b => [2, 20])
  $form = $TL->newForm('http://foo.com/?a=1&b=2&b=20')

TL::Form オブジェクトを作成。
三番目の形式ではURLからクエリ情報がデコードされる。

=item const

  $form->const

このメソッドを呼び出すと、以後フォームデータの変更は不可能となる。

=item clone

  $NewForm_obj = $form->clone

フォームオブジェクトの複製を返す。

=item addForm

  $form->addForm($another_form)

フォームに別のフォームデータを追加する。同じキーが存在した場合、
そのキーのデータは置き換えられる。

=item getKeys

  @keys = $form->getKeys

フォームのキー一覧を返す。ここで返すキーには、アップロードされたファイ
ルに付けられたものは含まない。

=item get

  $value = $form->get($key)
  $value = $form->get($key, $joinstr)

指定したキーの値を $joinstr で結合して返す。$joinstr省略時は "," が使用
される。$key が存在しない場合は undef を返す。ファイルのキーを指定した
場合も undef を返す。

=item getValues

  @values = $form->getValues($key)

指定したキーの値を配列で返す。
$key が存在しない場合は () を返す。

=item getSlice

  %data = $form->getSlice(@keys)

指定した複数キーに対して、キーと値が１つなら値そのものを、値が複数なら
複数の値の配列へのリファレンスのペアを、ハッシュとして返す。
存在しないキーは無視される。

=item getSliceValues

  @values = $form->getSliceValues(@keys)

指定した複数キーに対して、値が１つなら値そのものを、値が複数なら
複数の値の配列へのリファレンスを対応させて、配列として返す。
存在しないキーに対しては、それに対応する値はundefになる。

=item lookup

  $flag = $form->lookup($key, $value)

指定されたキーに指定された値があれば、1を。そうでなければundefを返す。
$keyが存在しなくてもエラーとはならない。

=item set

  $form->set($key => $value, $key2 => $value2, ...)
  $form->set($key => \@value, $key2 => \@value2, ...)

指定されたキーに、指定された値をセットする。
以前の値は失われる。（上書きされる）

=item add

  $form->add($key => $value, $key2 => $value2, ...)
  $form->add($key => \@value, $key2 => \@value2, ...)

指定されたキーに、指定された値を追加する。
以前の値は失われない。（追加される）

=item exists

  $flag = $form->exists($key)

キーが存在すれば1を、そうでなければundefを返す。

=item remove

  $form->remove($key, $value)

指定されたキーから、指定された値を取り除く。
指定されたキーや値がない場合は何もしない。

=item delete

  $form->delete($key)

指定されたキーを削除する。キーが存在しない場合は何もしない。

=item getFile

  $iohandle = $form->getFile($key);

キーに対応するIOハンドルを取り出す。ファイルアップロード時のみ取得でき
る。ファイルアップロードではなかった場合や、キーが存在しない場合は
undef を返す。

=item setFile

  $form->setFile($key, $iohandle);

指定したキーにIOハンドルをセットする。

=item getFileKeys

  @keys = $form->getFileKeys();

アップロードされたファイルのキー一覧を返す。

=item getFileName

  $filename = $form->getFileName($key)

キーに対応するファイル名を取り出す。ファイルアップロード時のみ取得でき
る。ファイルアップロードではなかった場合や、キーが存在しない場合は
undef を返す。

=item setFileName

  $form->setFileName($key => $value)

指定したキーにファイル名をセットする。

=item setLink

  $form->setLink('http://.../?a=1&b=2')

URLからデコードして得られたキーと値のペアで、古い値を置き換える。

=item addLink

  $form->addLink('http://.../?a=1&b=2')

URLからデコードして得られたキーと値のペアを追加する。

=item setFragment

  $form->setFragment($fragment)
  $form->setFragment(undef)

URLのフラグメントを設定する。これはtoLinkの結果に影響する。

=item getFragment

  $fragment = $form->getFragment;

URLのフラグメントを取得する。

=item toLink

  $url = $form->toLink($base)

フォームデータをURLの形式に変換し返す。$baseを指定すると、そのURLの後に
「?key=value」形式でデータを追加する。$baseを省略もしくはundefを指定すると、
自分自身へのリンクを返す。

URLが指し示す先はTLフレームワークで作成されたアプリケーションであると見なし、
文字コード判別用のデータを付与する。
TLフレームワークで作成されたアプリケーション以外へのリンクを作成する場合は、
toExtLinkメソッドを利用すること。

フラグメントが存在する場合は、それが #xxx の形でURLの中に組み込まれる。

=item toExtLink

  $url = $form->toExtLink($base)
  $url = $form->toExtLink($base, $code)

フォームデータをURLの形式に変換し返す。$baseを指定すると、そのURLの後に
「?key=value」形式でデータを追加する。$baseを省略もしくはundefを指定すると、
自分自身へのリンクを返す。

$codeで文字コードを指定すると、文字コードを変換してからURLエンコードする。
指定しなかった場合は UTF-8 コードで出力する。

フラグメントが存在する場合は、それが #xxx の形でURLの中に組み込まれる。

=item haveSessionCheck

  $result = $form->haveSessionCheck($sessiongroup)
  $result = $form->haveSessionCheck($sessiongroup, $issecure)

指定したセッショングループのセッションIDを利用したキーが現在フォームに埋め込まれているかを確認する。
埋め込まれていれば、1を。いなければ、undefを返す。
$Template->addSessionCheck とペアで使用する。

指定したセッショングループのIniで設定するcsrfkeyを必要とする。未設定の場合エラーとなる。
csrfkeyとセッションIDを利用してキーを作成する為、csrfkeyはサイト毎に違う値を用い、外部に漏れないようにする事。

使用中のセッションの mode が 'double' の場合は、
第2引数に 0 または 1 を指定すると、http側、https側を指定できる。
省略した場合は、そのときの通信が http/https のどちらであるかによって選択される。

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

