displines = 5;
local i = {};
local inp ={};
local StartFrame = emu.framecount();
local RecFrames = 0;
for n=3,0,-1 do
	
	i[1+n*8] = "P"..(n+1).." Up";
	i[2+n*8] = "P"..(n+1).." Down"; 
	i[3+n*8] = "P"..(n+1).." Left"; 
	i[4+n*8] = "P"..(n+1).." Right";
	i[5+n*8] = "P"..(n+1).." Button 1";
	i[6+n*8] = "P"..(n+1).." Button 2"; 
	i[7+n*8] = "P"..(n+1).." Start"; 
	i[8+n*8] = "P"..(n+1).." Coin"; 
end
currRec = 5;
local tabinp = {'up','down','left','right','comma','period','C','V'};
local visualtbl = {'^','v','<','>','O','O'}
local NameTable = {'Marge','Homer','Bart','Lisa','None','All'};


--*****************************************************************************
function press(button)
--*****************************************************************************
-- Checks if a button is pressed.
-- The tables it accesses should be obvious in the next line.

    if keys[button] and not last_keys[button] then
        return true

    end
    return false
end

keys, last_keys = {}, {};
AllFrames = {};
function test()
	keys = input.get();
	RF = {};		
	if keys['pageup'] then
		currRec = currRec + 1;
		if currRec > 4 then currRec = 1; end;
	elseif keys['pagedown'] then
		currRec = currRec - 1;
		if currRec == 0 then currRec = 4; end;		
	elseif keys['Z'] then
		currRec = 5;
	elseif keys['X'] then
		currRec = 6;
	elseif keys['numpad1'] then
		currRec = 1;
	elseif keys['numpad2'] then
		currRec = 2;
	elseif keys['numpad3'] then
		currRec = 3;
	elseif keys['numpad4'] then
		currRec = 4;
	
	end;
	if movie.mode() ~= 'playback' then							
		for n = 3,0,-1 do
			if currRec == n+1 or currRec == 6 then 
				m = 0;
				for j = 8,1,-1 do				
					m = m * 2;
					if keys[tabinp[j]] then 
						inp[i[j+n*8]] = true;
						m = m+1;
					else			
	   					inp[i[j+n*8]] = false;
	   				end;			
	   			end;			
				RF[n+1] = m;
			else						
				if (emu.framecount()-StartFrame) >= RecFrames then
					for j = 8,1,-1 do				
						inp[i[j+n*8]] = false;
					end;
					RF[n+1] = 0;
				else			
					TF = AllFrames[emu.framecount()-StartFrame+1];	
					control = TF[n+1];							
					for j = 1,8,1 do 
						if math.mod(control,2) == 1 then
							inp[i[j+n*8]] = true;
						else
							inp[i[j+n*8]] = false;
						end;
						control = math.floor(control/2);
					end;
					RF[n+1] = TF[n+1];	
				end;				
			end;
		end;	
	AllFrames[emu.framecount()-StartFrame+1] = RF;
	end;				
	joypad.set(inp);		
	RecFrames = math.max(RecFrames, emu.framecount()-StartFrame);		
	--gui.text(1,1,'Recording: ' .. NameTable[currRec]);
	last_keys = keys;
end;


function afterframe()
	inpm = joypad.get();				
	if movie.mode() == 'playback' then	
		RF = {};	
		for n = 3,0,-1 do
			m = 0;
			for j = 8,1,-1 do
				if inpm[i[j+n*8]] then
				z = 1 else z = 0; end;
				m = m*2; 
				m = m + z;
			end;		
			RF[n+1] = m;
		end;
		AllFrames[emu.framecount()-StartFrame] = RF;	
		RecFrames = math.max(RecFrames, emu.framecount()-StartFrame);		
	end;
	for k = 3,0,-1 do			
			for  l = 1,6,1 do
				if not inpm[i[l+k*8]] then
				  gui.text(10+k*70+l*7,20,visualtbl[l],'black')
				else
				  gui.text(10+k*70+l*7,20,visualtbl[l],'red')
				end;
						
			end;		
	end;		
	for FL = 1,math.min(displines,RecFrames - (emu.framecount()-StartFrame)),1 do
		FData = AllFrames[emu.framecount()-StartFrame+FL];
		
		for k = 3,0,-1 do
					ct = FData[k+1];							
					for l = 1,6,1 do 
						if math.mod(ct,2) == 1 then
					  		gui.text(10+k*70+l*7,20+FL*7,visualtbl[l],'red')
						end;
						ct = math.floor(ct/2);
					end;
		end;
	end;
gui.text(1,1,'Recording: ' .. NameTable[currRec]);		
end;

emu.registerbefore(test);

while true do
	emu.frameadvance();	
	afterframe();	
end;