unit parser;

interface

uses
  Classes, SysUtils, defs;

procedure getsym;
procedure block(lev, tx: integer; fsys: symset);
procedure error(n: integer);
procedure initparser(pl0filename: string);
procedure exitparser;

var
  sym: symbol;      {last symbol read}

implementation

uses codegen;

const
  POS_NOT_FOUND = 0;

var
  ch: char;         {last character read}
  id: alfa;         {last identifier read}
  num: integer;     {last number read}
  word: array [1..NUM_RES_WORDS] of alfa;
  wsym: array [1..NUM_RES_WORDS] of symbol;
  line: array [1..81] of char;
  ssym: array [char] of symbol;
  srcfile: TextFile;


procedure error(n: integer);
begin
  writeln(' ****', ' ': cc - 1, '^', n: 2, ': ', ERR_MSGS[n]);
  err := err + 1;
end {error};


procedure getsym;
var
  i, j, k: integer;

  procedure getch;
  begin
    if cc = ll then
    begin
      if EOF(srcfile) then
      begin
        Write(' program incomplete');
        exitprog;
      end;
      ll := 0;
      cc := 0;
      Write(cx: 5, ' ');
      while not eoln(srcfile) do
      begin
        ll := ll + 1;
        Read(srcfile, ch);
        Write(ch);
        line[ll] := ch;
      end;
      writeln;
      readln(srcfile);
      ll := ll + 1;
      line[ll] := ' ';
    end;
    cc := cc + 1;
    ch := line[cc];
  end {getch};

begin {getsym}
  while ch = ' ' do
    getch;
  if ch in ['a'..'z'] then
  begin {identifier or reserved word}
    k := 0;
    repeat
      if k < IDENTIFIER_LEN then
      begin
        k := k + 1;
        a[k] := ch;
      end;
      getch;
    until not (ch in ['a'..'z', '0'..'9']);
    if k >= kk then
      kk := k
    else
      repeat
        a[kk] := ' ';
        kk := kk - 1
      until kk = k;
    id := a;
    i := 1;
    j := NUM_RES_WORDS;
    repeat
      k := (i + j) div 2;
      if id <= word[k] then
        j := k - 1;
      if id >= word[k] then
        i := k + 1
    until i > j;
    if i - 1 > j then
      sym := wsym[k]
    else
      sym := ident;
  end
  else
  if ch in ['0'..'9'] then
  begin {number}
    k := 0;
    num := 0;
    sym := number;
    repeat
      num := 10 * num + (Ord(ch) - Ord('0'));
      k := k + 1;
      getch
    until not (ch in ['0'..'9']);
    if k > MAX_DIGITS_IN_NUM then
      error(30);
  end
  else
  if ch = ':' then
  begin
    getch;
    if ch = '=' then
    begin
      sym := becomes;
      getch;
    end
    else
      sym := nul;
  end
  else
  begin
    sym := ssym[ch];
    getch;
  end;
end {getsym};

procedure test(s1, s2: symset; n: integer);
begin
  if not (sym in s1) then
  begin
    error(n);
    s1 := s1 + s2;
    while not (sym in s1) do
      getsym;
  end;
end {test};

procedure block(lev, tx: integer; fsys: symset);
var
  dx: integer;     {data allocation index}
  tx0: integer;     {initial table index}
  cx0: integer;     {initial code index}

  procedure enter(k: Obj);
  begin {enter object into table}
    tx := tx + 1;
    with table[tx] do
    begin
      Name := id;
      kind := k;
      case k of
        constant:
        begin
          if num > ADDR_MAX then
          begin
            error(30);
            num := 0;
          end;
          val := num;
        end;
        variable:
        begin
          level := lev;
          adr := dx;
          dx := dx + 1;
        end;
        proc: level := lev
      end;
    end;
  end {enter};

  function position(id: alfa): integer;
  var
    i: integer;
  begin {find indentifier id in table}
    table[POS_NOT_FOUND].Name := id;
    i := tx;
    while table[i].Name <> id do
      i := i - 1;
    Result := i;
  end {position};

  procedure constdeclaration;
  begin
    if sym = ident then
    begin
      getsym;
      if sym in [eql, becomes] then
      begin
        if sym = becomes then
          error(1);
        getsym;
        if sym = number then
        begin
          enter(constant);
          getsym;
        end
        else
          error(2);
      end
      else
        error(3);
    end
    else
      error(4);
  end {constdeclaration};

  procedure vardeclaration;
  begin
    if sym = ident then
    begin
      enter(variable);
      getsym;
    end
    else
      error(4);
  end {vardeclaration};

  procedure listcode;
  var
    i: integer;
  begin {list code generated for this block}
    for i := cx0 to cx - 1 do
      with code[i] do
        writeln(i: 5, mnemonic[f]: 5, l: 3, a: 5);
  end {listcode};

  procedure statement(fsys: symset);
  var
    i, cx1, cx2: integer;

    procedure expression(fsys: symset);
    var
      addop: symbol;

      procedure term(fsys: symset);
      var
        mulop: symbol;

        procedure factor(fsys: symset);
        var
          i: integer;
        begin
          test(facbegsys, fsys, 24);
          while sym in facbegsys do
          begin
            if sym = ident then
            begin
              i := position(id);
              if i = POS_NOT_FOUND then
                error(11)
              else
                with table[i] do
                  case kind of
                    constant: gen(lit, 0, val);
                    variable: gen(lod, lev - level, adr);
                    proc: error(21)
                  end;
              getsym;
            end
            else
            if sym = number then
            begin
              if num > ADDR_MAX then
              begin
                error(30);
                num := 0;
              end;
              gen(lit, 0, num);
              getsym;
            end
            else
            if sym = lparen then
            begin
              getsym;
              expression([rparen] + fsys);
              if sym = rparen then
                getsym
              else
                error(22);
            end;
            test(fsys, [lparen], 23);
          end;
        end {factor};

      begin {term}
        factor(fsys + [times, slash]);
        while sym in [times, slash] do
        begin
          mulop := sym;
          getsym;
          factor(fsys + [times, slash]);
          if mulop = times then
            gen(opr, 0, 4)
          else
            gen(opr, 0, 5);
        end;
      end {term};
    begin {expression}
      if sym in [plus, minus] then
      begin
        addop := sym;
        getsym;
        term(fsys + [plus, minus]);
        if addop = minus then
          gen(opr, 0, 1);
      end
      else
        term(fsys + [plus, minus]);
      while sym in [plus, minus] do
      begin
        addop := sym;
        getsym;
        term(fsys + [plus, minus]);
        if addop = plus then
          gen(opr, 0, 2)
        else
          gen(opr, 0, 3);
      end;
    end {expression};

    procedure condition(fsys: symset);
    var
      relop: symbol;
    begin
      if sym = oddsym then
      begin
        getsym;
        expression(fsys);
        gen(opr, 0, 6);
      end
      else
      begin
        expression([eql, neq, lss, gtr, leq, geq] + fsys);
        if not (sym in [eql, neq, lss, leq, gtr, geq]) then
          error(20)
        else
        begin
          relop := sym;
          getsym;
          expression(fsys);
          case relop of
            eql: gen(opr, 0, 8);
            neq: gen(opr, 0, 9);
            lss: gen(opr, 0, 10);
            geq: gen(opr, 0, 11);
            gtr: gen(opr, 0, 12);
            leq: gen(opr, 0, 13);
          end;
        end;
      end;
    end {condition};

  begin {statement}
    if sym = ident then
    begin
      i := position(id);
      if i = POS_NOT_FOUND then
        error(11)
      else
      if table[i].kind <> variable then
      begin {assignment to non-variable}
        error(12);
        i := 0;
      end;
      getsym;
      if sym = becomes then
        getsym
      else
        error(13);
      expression(fsys);
      if i <> 0 then
        with table[i] do
          gen(sto, lev - level, adr);
    end
    else
    if sym = callsym then
    begin
      getsym;
      if sym <> ident then
        error(14)
      else
      begin
        i := position(id);
        if i = POS_NOT_FOUND then
          error(11)
        else
          with table[i] do
            if kind = proc then
              gen(cal, lev - level, adr)
            else
              error(15);
        getsym;
      end;
    end
    else
    if sym = ifsym then
    begin
      getsym;
      condition([thensym, dosym] + fsys);
      if sym = thensym then
        getsym
      else
        error(16);
      cx1 := cx;
      gen(jpc, 0, 0);
      statement(fsys);
      code[cx1].a := cx;
    end
    else
    if sym = beginsym then
    begin
      getsym;
      statement([semicolon, endsym] + fsys);
      while sym in [semicolon] + statbegsys do
      begin
        if sym = semicolon then
          getsym
        else
          error(10);
        statement([semicolon, endsym] + fsys);
      end;
      if sym = endsym then
        getsym
      else
        error(17);
    end
    else
    if sym = whilesym then
    begin
      cx1 := cx;
      getsym;
      condition([dosym] + fsys);
      cx2 := cx;
      gen(jpc, 0, 0);
      if sym = dosym then
        getsym
      else
        error(18);
      statement(fsys);
      gen(jmp, 0, cx1);
      code[cx2].a := cx;
    end
    else if sym = writesym then
    begin
      getsym;
      expression(fsys);
      gen(opr, 0, 15);
    end
    else if sym = readsym then
    begin
      getsym;
      if sym <> ident then
        error(26)
      else
      begin
        i := position(id);
        if i = POS_NOT_FOUND then
          error(11)
        else
        begin
          gen(opr, 0, 14);
          with table[i] do
            if kind = variable then
              gen(sto, lev - level, adr)
            else
              error(27);
        end;
        getsym;
      end;
    end;
    test(fsys, [], 19);
  end {statement};

begin {block}
  dx := 3;
  tx0 := tx;
  table[tx].adr := cx;
  gen(jmp, 0, 0);
  if lev > MAX_BLOCK_NESTING then
    error(32);
  repeat
    if sym = constsym then
    begin
      getsym;
      repeat
        constdeclaration;
        while sym = comma do
        begin
          getsym;
          constdeclaration;
        end;
        if sym = semicolon then
          getsym
        else
          error(5)
      until sym <> ident;
    end;
    if sym = varsym then
    begin
      getsym;
      repeat
        vardeclaration;
        while sym = comma do
        begin
          getsym;
          vardeclaration;
        end;
        if sym = semicolon then
          getsym
        else
          error(5)
      until sym <> ident;
    end;
    while sym = procsym do
    begin
      getsym;
      if sym = ident then
      begin
        enter(proc);
        getsym;
      end
      else
        error(4);
      if sym = semicolon then
        getsym
      else
        error(5);
      block(lev + 1, tx, [semicolon] + fsys);
      if sym = semicolon then
      begin
        getsym;
        test(statbegsys + [ident, procsym], fsys, 6);
      end
      else
        error(5);
    end;
    test(statbegsys + [ident], declbegsys, 7)
  until not (sym in declbegsys);
  code[table[tx0].adr].a := cx;
  with table[tx0] do
  begin
    adr := cx; {start adr of code}
  end;
  cx0 := 0{cx};
  gen(int, 0, dx);
  statement([semicolon, endsym] + fsys);
  gen(opr, 0, 0); {return}
  test(fsys, [], 8);
  listcode;
end {block};

procedure initparser(pl0filename: string);
begin
  AssignFile(srcfile, pl0filename);
  Reset(srcfile);
  for ch := chr(0) to chr(255) do
    ssym[ch] := nul;
  word[1] := 'begin     ';
  word[2] := 'call      ';
  word[3] := 'const     ';
  word[4] := 'do        ';
  word[5] := 'end       ';
  word[6] := 'if        ';
  word[7] := 'odd       ';
  word[8] := 'procedure ';
  word[9] := 'then      ';
  word[10] := 'var       ';
  word[11] := 'while     ';
  wsym[1] := beginsym;
  wsym[2] := callsym;
  wsym[3] := constsym;
  wsym[4] := dosym;
  wsym[5] := endsym;
  wsym[6] := ifsym;
  wsym[7] := oddsym;
  wsym[8] := procsym;
  wsym[9] := thensym;
  wsym[10] := varsym;
  wsym[11] := whilesym;
  ssym['+'] := plus;
  ssym['-'] := minus;
  ssym['*'] := times;
  ssym['/'] := slash;
  ssym['('] := lparen;
  ssym[')'] := rparen;
  ssym['='] := eql;
  ssym[','] := comma;
  ssym['.'] := period;
  ssym['#'] := neq;
  ssym['<'] := lss;
  ssym['>'] := gtr;
  ssym['['] := leq;
  ssym[']'] := geq;
  ssym[';'] := semicolon;
  ssym['!'] := writesym;
  ssym['?'] := readsym;
  mnemonic[lit] := '  lit';
  mnemonic[opr] := '  opr';
  mnemonic[lod] := '  lod';
  mnemonic[sto] := '  sto';
  mnemonic[cal] := '  cal';
  mnemonic[int] := '  int';
  mnemonic[jmp] := '  jmp';
  mnemonic[jpc] := '  jpc';
  declbegsys := [constsym, varsym, procsym];
  statbegsys := [beginsym, callsym, ifsym, whilesym];
  facbegsys := [ident, number, lparen];
  err := 0;
  cc := 0;
  cx := 0;
  ll := 0;
  ch := ' ';
  kk := IDENTIFIER_LEN;
end;

procedure exitparser;
begin
  CloseFile(srcfile);
end;

end.
