unit codegen;

interface

uses
  Classes, SysUtils, defs;

procedure gen(x: fct; y, z: integer);

implementation

procedure gen(x: fct; y, z: integer);
begin
  if cx > CODE_ARR_SIZE then
  begin
    Write(' program too long');
    exitprog;
  end;
  with code[cx] do
  begin
    f := x;
    l := y;
    a := z;
  end;
  cx := cx + 1;
end {gen};


end.

