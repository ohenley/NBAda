-------------------------------------------------------------------------------
--  Example Stack - A lock-free stack using hazard pointers.
--  Copyright (C) 2005 - 2008  Anders Gidenstam
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--
-------------------------------------------------------------------------------
--                              -*- Mode: Ada -*-
--  Filename        : stack_test.adb
--  Description     : Test of the lock-free example stack.
--  Author          : Anders Gidenstam
--  Created On      : Fri Sep 23 18:54:53 2005
--  $Id: stack_test.adb,v 1.6.2.1 2008/09/17 20:52:04 andersg Exp $
-------------------------------------------------------------------------------

pragma License (GPL);

with NBAda.Process_Identification;
with NBAda.Primitives;

with Ada.Text_IO;
with Ada.Exceptions;

with Ada.Real_Time;

with Example_Stack;

procedure Stack_Test is

   use NBAda;

   package PID is
      new Process_Identification (Max_Number_Of_Processes => 32);


   type Value_Type is
      record
         Creator : PID.Process_ID_Type;
         Index   : Integer;
      end record;
   package Stacks is new Example_Stack (Element_Type => Value_Type,
                                        Process_Ids  => PID);
   use Stacks;

   ----------------------------------------------------------------------------
   --  Test application.
   ----------------------------------------------------------------------------

   No_Of_Elements : constant := 100_000;
   STACK_LIFO_PROPERTY_VIOLATION : exception;

   Output_File : Ada.Text_IO.File_Type renames
     Ada.Text_IO.Standard_Output;
--     Ada.Text_IO.Standard_Error;

   task type Pusher is
      pragma Storage_Size (1 * 1024 * 1024);
   end Pusher;

   task type Popper is
      pragma Storage_Size (1 * 1024 * 1024);
   end Popper;

   Stack                : aliased Stacks.Stack_Type;

   Start                : aliased Primitives.Unsigned_32 := 0;
   pragma Atomic (Start);
   Push_Count           : aliased Primitives.Unsigned_32 := 0;
   pragma Atomic (Push_Count);
   Pop_Count            : aliased Primitives.Unsigned_32 := 0;
   pragma Atomic (Pop_Count);
   No_Pushers_Running   : aliased Primitives.Unsigned_32 := 0;
   pragma Atomic (No_Pushers_Running);
   No_Poppers_Running   : aliased Primitives.Unsigned_32 := 0;
   pragma Atomic (No_Poppers_Running);

   ----------------------------------------------------------------------------
   task body Pusher is
      No_Pushes : Primitives.Unsigned_32 := 0;
   begin
      PID.Register;
      Primitives.Fetch_And_Add_32 (No_Pushers_Running'Access, 1);

      declare
         use type Primitives.Unsigned_32;
      begin
         while Start = 0 loop
            null;
         end loop;
      end;

      declare
         ID          : constant PID.Process_ID_Type := PID.Process_ID;
      begin
         for I in 1 .. No_Of_Elements loop
            Push (Stack, Value_Type'(ID, I));
            No_Pushes := Primitives.Unsigned_32'Succ (No_Pushes);
         end loop;

      exception
         when E : others =>
            Ada.Text_IO.New_Line (Output_File);
            Ada.Text_IO.Put_Line (Output_File,
                                  "Pusher (" &
                                  PID.Process_ID_Type'Image (ID) &
                                  "): raised " &
                                  Ada.Exceptions.Exception_Name (E) &
                                  " : " &
                                  Ada.Exceptions.Exception_Message (E));
            Ada.Text_IO.New_Line (Output_File);
      end;
      declare
         use type Primitives.Unsigned_32;
      begin
         Primitives.Fetch_And_Add_32 (Push_Count'Access, No_Pushes);
         Primitives.Fetch_And_Add_32 (No_Pushers_Running'Access, -1);
      end;
      Ada.Text_IO.Put_Line (Output_File,
                            "Pusher (?): exited.");

   exception
      when E : others =>
         Ada.Text_IO.New_Line (Output_File);
         Ada.Text_IO.Put_Line (Output_File,
                               "Pusher (?): raised " &
                               Ada.Exceptions.Exception_Name (E) &
                               " : " &
                               Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line (Output_File);
   end Pusher;

   ----------------------------------------------------------------------------
   task body Popper is
      No_Pops : Primitives.Unsigned_32 := 0;
   begin
      PID.Register;
      Primitives.Fetch_And_Add_32 (No_Poppers_Running'Access, 1);

      declare
         ID   : constant PID.Process_ID_Type := PID.Process_ID;
         Last : array (PID.Process_ID_Type) of Integer := (others => 0);
         V    : Value_Type;
         Done : Boolean := False;
      begin

         declare
            use type Primitives.Unsigned_32;
         begin
            while Start = 0 loop
               null;
            end loop;
         end;

         loop

            begin
               V       := Pop (Stack'Access);
               No_Pops := Primitives.Unsigned_32'Succ (No_Pops);

               Done := False;

--                 if V.Index <= Last (V.Creator) then
--                    raise QUEUE_FIFO_PROPERTY_VIOLATION;
--                 end if;
--                 Last (V.Creator) := V.Index;

            exception
               when Stacks.Stack_Empty =>
                  Ada.Text_IO.Put (".");
                  declare
                     use type Primitives.Unsigned_32;
                  begin
--                     exit when Done and No_Pushers_Running = 0;
                     exit when No_Pushers_Running = 0;
                  end;
                  delay 0.0;

                  Done := True;
            end;
         end loop;

      exception
         when E : others =>
            Ada.Text_IO.New_Line (Output_File);
            Ada.Text_IO.Put_Line (Output_File,
                                  "Popper (" &
                                  PID.Process_ID_Type'Image (ID) &
                                  "): raised " &
                                  Ada.Exceptions.Exception_Name (E) &
                                  " : " &
                                  Ada.Exceptions.Exception_Message (E));
            Ada.Text_IO.New_Line (Output_File);
      end;

      declare
         use type Primitives.Unsigned_32;
      begin
         Primitives.Fetch_And_Add_32 (Pop_Count'Access, No_Pops);
         Primitives.Fetch_And_Add_32 (No_Poppers_Running'Access, -1);
      end;

      Ada.Text_IO.Put_Line (Output_File,
                            "Popper (?): exited.");
   exception
      when E : others =>
         Ada.Text_IO.New_Line (Output_File);
         Ada.Text_IO.Put_Line (Output_File,
                               "Consumer (?): raised " &
                               Ada.Exceptions.Exception_Name (E) &
                               " : " &
                               Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line (Output_File);
   end Popper;

   use type Ada.Real_Time.Time;
   T1, T2 : Ada.Real_Time.Time;
begin
   PID.Register;

   Ada.Text_IO.Put_Line ("Testing with pusher/popper tasks.");
   declare
      use type Primitives.Unsigned_32;
--      P1, P2, P3, P4 : Pusher;
--      C1, C2, C3, C4 : Popper;
      P0, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14
        : Pusher;
      C0, C1, C2, C3, C4, C5, C6, C7, C8, C9, C10, C11, C12, C13, C14
        : Popper;
   begin
      delay 5.0;
      T1 := Ada.Real_Time.Clock;
      Primitives.Fetch_And_Add_32 (Start'Access, 1);
   end;

   T2 := Ada.Real_Time.Clock;


   delay 1.0;
   Ada.Text_IO.Put_Line ("Push count: " &
                         Primitives.Unsigned_32'Image (Push_Count));
   Ada.Text_IO.Put_Line ("Pop count: " &
                         Primitives.Unsigned_32'Image (Pop_Count));
   Ada.Text_IO.Put_Line ("Elapsed time:" &
                         Duration'Image (Ada.Real_Time.To_Duration (T2 - T1)));

   Ada.Text_IO.Put_Line ("Emptying stack.");
   delay 5.0;

   declare
      V : Value_Type;
   begin
      loop
         V := Pop (Stack'Access);
         Ada.Text_IO.Put_Line (Output_File,
                               "Pop() = (" &
                               PID.Process_ID_Type'Image (V.Creator) & ", " &
                               Integer'Image (V.Index) & ")");
         Primitives.Fetch_And_Add_32 (Pop_Count'Access, 1);
      end loop;
   exception
      when E : others =>
         Ada.Text_IO.New_Line (Output_File);
         Ada.Text_IO.Put_Line (Output_File,
                               "raised " &
                               Ada.Exceptions.Exception_Name (E) &
                               " : " &
                               Ada.Exceptions.Exception_Message (E));
         Ada.Text_IO.New_Line (Output_File);

         Ada.Text_IO.Put_Line ("Final push count: " &
                               Primitives.Unsigned_32'Image (Push_Count));
         Ada.Text_IO.Put_Line ("Final pop count: " &
                               Primitives.Unsigned_32'Image (Pop_Count));
   end;
end Stack_Test;
