unit main;

interface

uses
  Classes, SysUtils;

procedure mainprog(pl0filename: string);

implementation

uses defs, parser, interpreter;

procedure mainprog(pl0filename: string);
begin
  initparser(pl0filename);
  getsym;
  block(0, 0, [period] + declbegsys + statbegsys);
  exitparser;
  if sym <> period then
    error(9);
  if err = 0 then
    interpret
  else
    Write(' errors in pl/0 program');
  writeln;
end;

end.


