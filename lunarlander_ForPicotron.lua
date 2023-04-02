dev=false
ver="0.14" -- 2023/04/02
--[[
v0.14 (2023/04/02)
- 지형을 거대한 원형으로 그림
- 지형 확대축소할 때 LOD 처리
- 지형 데이타 조금 더 추가

v0.13 (2023/04/01)
- 지형 화면에 꽉 채워서 그리기

v0.11 (2023/03/12~14)
- 지형 2탄 그려보는 중(더 디테일하게...)
- scale_x 조정하다 보면 배경 가림 세로선에 빈틈이 생기는 경우가 있음 -> 좌표 반올림으로 해결

v0.1 (2023/02)
- fps 확인용 임시 지형 그려보는 중
]] 

-- <Ref.>
-- https://youtu.be/11Zf0_2TgXw
-- https://youtu.be/T1z-Rp7nxqA -- 3D Simulation
-- https://youtu.be/oX8-IXdABuc -- Lunar Module
-- https://youtu.be/7WAWY-DktT0 -- Apollo 14 Landing, Mooonwalk & Liftoff
-- https://youtu.be/6R3j1NU2nQM -- Moon in Google Earth
-- http://moonlander.seb.ly/ -- Game Play

sw,sh=480,270
cx,cy=sw/2,sh/2
log_txt={}

-- <Asteroids Font(5x7 Pixel)> --------------------
fnt_data_57=[[
00700070700000000700000007777000700000700700000000000000000000000000000000077777007007777777777700077777777777777777777777777000
00700070700707077777700077007000700007000070070007007000000000000000000000770007007000000700007700077000070000000077000770007000
00700000007777770000000707070000000070000007007070007000000000000000000007070007007000000700007700077000070000000077000770007000
00700000000707077777007000700000000070000007077777777770000077777000000070070007007007777777777777777777777777000077777777777000
00700000007777700007070007070700000070000007007070007000000000000000000700070007007007000000007000070000770007000077000700007000
00000000000707077777700077007000000007000070070007007000070000000000007000070007007007000000007000070000770007000077000700007000
00700000000000000700000007770700000000700700000000000000700000000007000000077777007007777777777000077777777777000077777777777000
00000000000000700000700007777707770007007777077777777007777777777777777000777777000077000770000700077000777777777777777777777000
00700007000007000000070007000770007070707000770000700707000070000700007000700700000077007070000770777000770007700077000770007000
00700007000070077777007000007070777700077007070000700077000070000700007000700700000077070070000707077700770007700077000770007000
00000000000700000000000700070070707700077770070000700077770077700707777777700700000077700070000700077070770007777777000777777000
00700007000070077777007000070070777777777007070000700077000070000700077000700700700077070070000700077007770007700007070770700000
00700007000007000000070000000070007700077000770000700707000070000700077000700700070077007070000700077000770007700007007070070000
00000070000000700000700000070007770700077777077777777007777770000777777000777777007777000777777700077000777777700007770770007000
77777777777000770007700077000770007777770777000000077700070000000007000077000700077000000007770000000000000000000000000000000000
70000007007000770007700070707007070000070700070000000700707000000000700070000700007000000070007000000000000000000000000000000000
70000007007000707070700070707000700000700700007000000707000700000000000070000700007000700007770000000000000000000000000000000000
77777007007000707070700070070000700007000700000700000700000000000000000700000000007707070707000000000000000000000000000000000000
00007007007000707070707070707000700070000700000070000700000000000000000070000700007000007007770000000000000000000000000000000000
00007007007000700700770770707000700700000700000007000700000000000000000070000700007000000070007000000000000000000000000000000000
77777007007777700700700077000700700777770777000000077700000077777000000077000700077000000007770000000000000000000000000000000000
]]
fnt57=userdata("[gfx]8115"..fnt_data_57) -- 0x81*0x15 크기의 이미지에...

function is_inside(v,min,max) return v>=min and v<=max end
function convert_ord_to_id(t) -- 글자에서 ord 값을 뽑아 스프라이트 id(0~68)로 바꿈
	local a=ord(t)
	if a==67 then a=68 -- 대문자C -> (C)문자
	elseif is_inside(a,33,96) then a-=32+1 -- 33~96번 문자 -> 스프라이트 0번부터 사용
	elseif is_inside(a,65,90) then a=-1 -- 대문자 -> 특수기호 외에는 버림
	elseif is_inside(a,97,122) then a-=65 -- 소문자 -> 대문자로 처리
	else a=-1 end -- 나머지는 공백 문자
	return a
end
--[[ function print79(t,x,y,c,align,big_size,draw_ratio,with_box)
	local id
	local gap=2
	local data,w,h,n=fnt57,5,7,25 -- 데이터(spr),글자하나의 가로,세로,이미지 한 줄에 있는 글자 수
	-- if(big_size) data,w,h,n=fnt79,7,9,18
	if(draw_ratio) t=sub(t,1,flr(#t*clamp(draw_ratio,0,1)))..((draw_ratio>0 and draw_ratio<1) and "_" or "")
	
	-- 글자 정렬
	local align=align and align or 0 -- 정렬 0 왼쪽부터, 0.5 중앙, 1 오른쪽부터
	local full_w=#t*w+(#t-1)*gap-1
	if align==0.5 then x=x-full_w/2 elseif align==1 then x=x-full_w end

	-- 테두리 박스
	if(with_box and #t>0) draw_shape(s_box,x-5,y+3,cc,0,false,1,{x=(full_w+10)/10,y=1.6})

	pal(7,c)
	for i=1,#t do
		id=convert_ord_to_id(sub(t,i,i))
		if id>=0 then
			local tx,ty=id%n*w,id\n*h
			sspr(data,tx,ty,w,h,x,y)
		end
		x+=w+gap
	end
	pal()
end ]]
-- 5x7 폰트 찍기
function print57(t,x,y,c,align,draw_ratio,with_box)
	local id
	local gap=2
	local data,w,h,n=fnt57,5,7,25 -- 데이터(spr),글자하나의 가로,세로,이미지 한 줄에 있는 글자 수
	if(draw_ratio) t=sub(t,1,flr(#t*clamp(draw_ratio,0,1)))..((draw_ratio>0 and draw_ratio<1) and "_" or "")
	
	-- 글자 정렬
	local align=align and align or 0 -- 정렬 0 왼쪽부터, 0.5 중앙, 1 오른쪽부터
	local full_w=#t*w+(#t-1)*gap-1
	if align==0.5 then x=x-full_w/2 elseif align==1 then x=x-full_w end

	-- 테두리 박스
	if(with_box and #t>0) draw_shape(s_box,x-5,y+3,cc,0,false,1,{x=(full_w+10)/10,y=1.6})

	pal(7,c)
	for i=1,#t do
		id=convert_ord_to_id(sub(t,i,i))
		if id>=0 then
			local tx,ty=id%n*w,id\n*h
			sspr(data,tx,ty,w,h,x,y)
		end
		x+=w+gap
	end
	pal()
end




-- <class helper> ----------------------------------------
function class(base)
	local nc={}
	if (base) setmetatable(nc,{__index=base}) 
	nc.new=function(...) 
		local no={}
		setmetatable(no,{__index=nc})
		local cur,q=no,{}
		repeat
			local mt=getmetatable(cur)
			if not mt then break end
			cur=mt.__index
			add(q,cur,1)
		until cur==nil
		for i=1,#q do
			if (rawget(q[i],'init')) rawget(q[i],'init')(no,...)
		end
		return no
	end
	return nc
end

-- event dispatcher
event=class()
function event:init()
	self._evt={}
end
function event:on(event,func,context)
	self._evt[event]=self._evt[event] or {}
	-- only one handler with same function
	self._evt[event][func]=context or self
end
function event:remove_handler(event,func,context)
	local e=self._evt[event]
	if (e and (context or self)==e[func]) e[func]=nil
end
function event:emit(event,...)
	for f,c in pairs(self._evt[event]) do
		f(c,...)
	end
end

-- sprite class for scene graph
sprite=class(event)
function sprite:init()
	self.children={}
	self.parent=nil
	self.x=0
	self.y=0
end
function sprite:set_xy(x,y)
	self.x=x
	self.y=y
end
function sprite:get_xy()
	return self.x,self.y
end
function sprite:add_child(child)
	child.parent=self
	add(self.children,child)
end
function sprite:remove_child(child)
	del(self.children,child)
	child.parent=nil
end
function sprite:remove_self()
	if self.parent then
		self.parent:remove_child(self)
	end
end
-- logical xor
function lxor(a,b) return not a~=not b end
-- common draw function
function sprite:_draw(x,y,fx,fy)
	spr(self.spr_idx,x+self.x,y+self.y,self.w or 1,self.h or 1,lxor(fx,self.fx),lxor(fy,self.fy))
end
function sprite:show(v)
	self.draw=v and self._draw or nil
end
function sprite:render(x,y,fx,fy)
	if (self.draw) self:draw(x,y,fx,fy)
	for i=1,#self.children do
		self.children[i]:render(x+self.x,y+self.y,lxor(fx,self.fx),lxor(fy,self.fy))
	end
end
function sprite:emit_update()
	self:emit("update")
	for i=1,#self.children do
		local child=self.children[i]
		if child then child:emit_update() end
	end
end

-- <utilities> ----------------------------------------
function round(n) return flr(n+.5) end
-- function round(n) return split(tostr(flr(n+.5)),".")[1] end -- Picotron에서 원래 방식이 동작을 안해서 이 방법을 씀
function swap(v) if v==0 then return 1 else return 0 end end -- 1 0 swap
function clamp(a,min_v,max_v) return min(max(a,min_v),max_v) end
function rndf(lo,hi) return lo+rnd()*(hi-lo) end -- random real number between lo and hi
function rndi(n) return flr(rnd(n)) end -- random int(0<=value<n)
function printa(t,x,y,c,align,shadow) -- 0.5 center, 1 right align
	x-=align*4*#(tostr(t))
	if (shadow) ?t,x+1,y+1,0
	?t,x,y,c
end










-- <shape data> ----------------------------------------
function str_to_arr(str,scale,pivot)
	local arr=split(str,",")
	local dx,dy,s=0,0,scale or 1
	local x1,x2,y1,y2

	-- pivot은 {x=0.5,y=0} 형식으로 설정
	if pivot then 
		x1,x2,y1,y2=arr[1],arr[1],arr[2],arr[2]
		for i=1,#arr,2 do
			if arr[i]!="x" then
				-- split() 버그 때문에 인자에 +0 해줌
				x1,x2=min(x1+0,arr[i]+0),max(x2+0,arr[i]+0)
				y1,y2=min(y1+0,arr[i+1]+0),max(y2+0,arr[i+1]+0)
			end
		end
		dx=-x1-(x2-x1)*pivot.x
		dy=-y1-(y2-y1)*pivot.y
	end

	-- scale과 pivot 적용
	for i=1,#arr,2 do
		if arr[i]!="x" then
			arr[i]=(arr[i]+dx)*s
			arr[i+1]=(arr[i+1]+dy)*s
		end
	end

	return arr
end
s_ufo_str="-1,-3,1,-3,2,-1,5,1,2,3,-2,3,-5,1,-2,-1,-1,-3,x,x,-2,-1,2,-1,x,x,-5,1,5,1"
s_ufo=str_to_arr(s_ufo_str,2)
s_ship2=str_to_arr("0,-4,4,4,0,2,-4,4,0,-4") -- remain ships
s_ship=str_to_arr("4,0,-4,4,-2,0,-4,-4,4,0")
s_thrust=str_to_arr("-1,-2,-10,0,-1,2")
s_shield=str_to_arr("0,-3,-2,-2,-3,0,-2,2,0,3,2,2,3,0,2,-2,0,-3",3)

s_ast1={} s_ast2={} s_ast3={}
s_ast1[1]=str_to_arr("4,0,2,-1,2,-3,-1,-4,-2,-2,-4,0,-2,1,-3,2,-2,4,0,3,2,4,4,0",3)
s_ast1[2]=str_to_arr("0,-4,-4,-2,-3,0,-3,3,0,4,1,2,3,2,4,-2,0,-4",3)
s_ast1[3]=str_to_arr("3,0,2,1,2,2,0,3,-2,2,-3,0,-2.5,-2,0,-3,2,-2,3,0",4)
s_ast1[4]=str_to_arr("3,0,1,3,-2,2,-2,1,-3,0,-1.5,-3,0,-3,2,-2,2,-1,3,0",4)
s_ast2[1]=str_to_arr("3,-3,4,0,3,3,0,3,-2,4,-3,3,-3,1,-4,-2,-1,-4,1,-3,3,-3",1.9)
s_ast2[2]=str_to_arr("2,-4,3,-1,4.5,1,2,2,1,4,-1,2.5,-4,2,-3,0,-3,-3,0,-3,2,-4",1.9)
s_ast2[3]=str_to_arr("4,0,2,4,0,3,-2,4,-4,2,-4,-2,-2,-4,0,-2,3,-3,4,0",1.8)
s_ast2[4]=str_to_arr("0,-4,-2,-2,-4,-2,-3,1,-3,3,1,4,2,1,4,-1,0,-4",1.9)
s_ast3[1]=str_to_arr("4,2,2,4,-4,0,-2,-4,3,-3,4,2",1)
s_ast3[2]=str_to_arr("-4,0,-2,-4,2,-4,4,-2,4,2,0,4,-4,0",0.95)
s_ast3[3]=str_to_arr("0,-4,-4,1,-2,4,4,1,0,-4",1)
s_ast3[4]=str_to_arr("0,-4,-2,-3,-3,3,1,4,4,-2,0,-4",1)

s_title_str="0,6,0,2,2,0,4,2,4,6,x,x,0,4,4,4,x,x,9,0,5,0,5,3,9,3,9,6,5,6,x,x,10,0,14,0,x,x,12,0,12,6" -- AST
s_title_str..=",x,x,19,0,15,0,15,6,19,6,x,x,15,3,18,3,x,x,20,6,20,0,24,0,24,3,20,3,x,x,21,3,24,6" -- ER
s_title_str..=",x,x,25,0,29,0,29,6,25,6,25,0,x,x,30,0,34,0,x,x,32,0,32,6,x,x,30,6,34,6" -- OI
s_title_str..=",x,x,35,0,37,0,39,2,39,4,37,6,35,6,35,0,x,x,44,0,40,0,40,3,44,3,44,6,40,6" -- DS
s_title=str_to_arr(s_title_str,4.5,{x=0.5,y=0.5})
s_demake=str_to_arr("0,0,2,0,4,2,4,4,2,6,0,6,0,0,x,x,9,0,5,0,5,6,9,6,x,x,5,3,8,3,x,x,10,6,10,0,12,2,14,0,14,6,x,x,15,6,15,2,17,0,19,2,19,6,x,x,15,4,19,4,x,x,20,0,20,6,x,x,24,0,20,3,24,6,x,x,29,0,25,0,25,6,29,6,x,x,25,3,28,3",4.5,{x=0.5,y=0.5})
s_2023=str_to_arr("0,0,4,0,4,3,0,3,0,6,4,6,x,x,5,0,9,0,9,6,5,6,5,0,x,x,10,0,14,0,14,3,10,3,10,6,14,6,x,x,15,0,19,0,19,6,15,6,x,x,15,3,19,3",4.5,{x=0.5,y=0.5})
s_game=str_to_arr("4,0,0,0,0,6,4,6,4,4,2,4,x,x,5,6,5,2,7,0,9,2,9,6,x,x,5,4,9,4,x,x,10,6,10,0,12,2,14,0,14,6,x,x,19,0,15,0,15,6,19,6,x,x,15,3,18,3",4)
s_over=str_to_arr("0,0,4,0,4,6,0,6,0,0,x,x,5,0,7,6,9,0,x,x,14,0,10,0,10,6,14,6,x,x,10,3,13,3,x,x,15,6,15,0,19,0,19,3,15,3,x,x,16,3,19,6",4)
s_box=str_to_arr("0,-1,2,-1,2,1,0,1,0,-1",5)
s_circle={}
for i=0,24 do
	local r=i/24
	local x,y=sin(r)*80,cos(r)*80
	add(s_circle,x)
	add(s_circle,y)
end
s_num={}
s_num["_"]=str_to_arr("0,4,2,4",3)
s_num["0"]=str_to_arr("0,0,2,0,2,4,0,4,0,0",3) --0
s_num["1"]=str_to_arr("1,0,1,4",3) -- 1
s_num["2"]=str_to_arr("0,0,2,0,2,2,0,2,0,4,2,4",3) -- 2
s_num["3"]=str_to_arr("0,0,2,0,2,2,x,x,0,2,2,2,2,4,0,4",3)
s_num["4"]=str_to_arr("0,0,0,2,2,2,x,x,2,0,2,4",3)
s_num["5"]=str_to_arr("2,0,0,0,0,2,2,2,2,4,0,4",3)
s_num["6"]=str_to_arr("2,0,0,0,0,4,2,4,2,2,0,2",3)
s_num["7"]=str_to_arr("0,0,2,0,2,4",3)
s_num["8"]=str_to_arr("0,0,2,0,2,4,0,4,0,0,x,x,0,2,2,2",3)
s_num["9"]=str_to_arr("2,2,0,2,0,0,2,0,2,4,0,4",3)
s_text_break=str_to_arr("0,0,4,4,8,0,12,4,16,0,20,4,24,0,28,4,32,0,36,4",2) -- /\/\/\ shape

-- s_cat_str="1,-2.5,2,-4,3,-2,4,-1,4,2,2,4,-2,4,-4,2,-4,-1,-3,-2,-2,-4,-1,-2.5,1,-2.5"
-- s_cat_str..=",x,x,-3,-0.5,-0.5,-0.5,-0.5,0.5,-1.75,1,-3,0.5,-3,-0.5,x,x,-1.75,-0.5,-1.75,0.5" -- eye l
-- s_cat_str..=",x,x,0.5,-0.5,3,-0.5,3,0.5,1.75,1,0.5,0.5,0.5,-0.5,x,x,1.75,-0.5,1.75,0.5" -- eye r
-- s_cat_str..=",x,x,-2,2,-1.5,2.5,-1,2.5,0,2,1,2.5,1.5,2.5,2,2,x,x,0,2,0,1.5" -- mouth
-- s_cat_str..=",x,x,2.5,1.5,5,1.5,x,x,2.5,2.5,5,3,x,x,-2.5,1.5,-5,1.5,x,x,-2.5,2.5,-5,3"
s_cat_str="4,-3,6,-7,10,-2.5,12,-1,13,3,12,8,5,11,-5,11,-12,8,-13,3,-12,-1,-10,-2.5,-6,-7,-4,-3,4,-3"
s_cat_str..=",x,x,3,0,10.5,0,10,2,6.5,3.5,4,2.5,3,0,x,x,6,0,6,2.5" -- eye l
s_cat_str..=",x,x,-3,0,-4,2.5,-6.5,3.5,-10,2,-10.5,0,-3,0,x,x,-6,0,-6,2.5" -- eye r
s_cat_str..=",x,x,-4,5,-4.5,6,-4,7.5,-2,8.5,-0.5,7.5,0,6,0.5,7.5,2,8.5,4,7.5,4.5,6,4,5" -- mouth
s_cat_str..=",x,x,10.5,3.5,16,3.5,x,x,10.5,5.5,15,8.5"
s_cat_str..=",x,x,-10.5,3.5,-16,3.5,x,x,-10.5,5.5,-15,8.5"
s_lunarlander_str="-1,3,-3,1,-3,-1,-1,-3,1,-3,3,-1,3,1,1,3,-1,3"
s_lunarlander_str..=",x,x,-1,-3,-1,4,-2,6,2,6,1,4,1,-3"
s_lunarlander_str..=",x,x,-5,7,-4,7,-2,3,2,3,4,7,5,7"
s_lunarlander_str..=",x,x,-3,-1,3,-1,x,x,-3,1,3,1,x,x,-1,4,1,4"
s_lunarlander=str_to_arr(s_lunarlander_str,4,{x=0.5,y=0.5})
-- s_debris={}
-- s_debris[1]=str_to_arr(s_lunarlander_str,4,{x=0.5,y=0.5})
-- s_debris[2]=str_to_arr(s_ufo_str,4)
-- s_debris[3]=str_to_arr(s_cat_str,5)






-- <space> ----------------------------------------
space=class(sprite)
function space:init()
	self.spd_x=0.3
	self.spd_y=0
	self.stars={}
	self.particles={}

	local function make_star(i,max,base_spd)
		return {
			x=rnd(sw),
			y=rnd(sh),
			spd=base_spd+i/max*base_spd,
			size=1+rnd(1),
			c=rnd()<0.2 and cc-5 or cc-7
		}
	end
	for i=1,140 do add(self.stars,make_star(i,100,1)) end
	self:show(true)
	self:on("update",self.on_update)
end

ptcl_size_explosion="56776655443321111000"

function space:_draw()
	-- stars
	for v in all(self.stars) do
		local x=v.x-self.spd_x*v.spd*gg.spd_multiplier
		local y=v.y+self.spd_y*v.spd
		v.x=x>sw+1 and x-sw-1 or x<-2 and x+sw+1 or x
		v.y=y>sh+1 and y-sh-1 or y<-2 and y+sh+1 or y
		-- if v.size>1.9 then circfill(v.x,v.y,1,rnd()<0.002 and cc-3 or v.c)
		-- else pset(v.x,v.y,rnd()<0.002 and cc-3 or v.c) end
		if rnd()<0.001 then -- twinkling +
			line(v.x-4,v.y,v.x+4,v.y,cc-7)
			line(v.x,v.y-4,v.x,v.y+4,cc-7)
			circ(v.x,v.y,1,cc-6)
			pset(v.x,v.y,cc-4)
		elseif v.size>1.9 then circfill(v.x,v.y,1,v.c)
		else pset(v.x,v.y,v.c) end
	end

	-- particles
	for i,v in pairs(self.particles) do
		if v.type=="thrust" then
			pset(v.x,v.y,cc)
			v.x+=v.sx+rnd(4)-2
			v.y+=v.sy+rnd(4)-2
			v.sx*=0.93
			v.sy*=0.93
			if(v.age>20) del(self.particles,v)

		elseif v.type=="bullet" or v.type=="bullet_ufo" then
			v.x+=v.sx
			v.y+=v.sy
			coord_loop(v)
			if v.type=="bullet_ufo" then
				local len=4*(v.age_max-v.age)/v.age_max
				line(v.x,v.y,v.x-v.sx*len,v.y-v.sy*len,cc)
				circ(v.x,v.y,1,cc)
			else pset(v.x,v.y,cc) end
			if(v.age>v.age_max) del(self.particles,v)

			-- 적과 충돌 처리
			local killed={}
			for e in all(_enemies.list) do
				local dist=(e.size==4) and 8 or (e.size==1) and 11 or (e.size==2) and 8 or 5
				if abs(v.x-e.x)<=dist and abs(v.y-e.y)<=dist and get_dist(v.x,v.y,e.x,e.y)<=dist then
					if(v.type=="bullet") score_up(e.size)
					if(e.size<3) add(killed,{x=e.x,y=e.y,size=e.size})
					add_break_eff(e.x,e.y,e.shape)
					add_explosion_eff(e.x,e.y,v.sx,v.sy)
					if(e.size==4) add_break_eff(e.x,e.y,s_ufo,2,40) add_explosion_eff(e.x,e.y,v.sx,v.sy,1.6,30)
					del(self.particles,v)
					del(_enemies.list,e)
					-- sfx(3,3)
				end
			end
			for e in all(killed) do
				-- 작은 소행성 2개로 분리
				local sx,sy=get_base_spd(rnd())
				_enemies:add(e.x+1,e.y+1,e.size+1,sx,sy)
				_enemies:add(e.x-1,e.y-1,e.size+1,-sx,-sy)
			end

			if v.type=="bullet_ufo" then
				-- ship과 충돌 처리
				local dist=4+(_ship.use_shield and 6 or 0)
				local x,y=_ship.x,_ship.y
				if abs(v.x-x)<=dist and abs(v.y-y)<=dist and get_dist(v.x,v.y,x,y)<=dist then
					if _ship.use_shield then
						_ship.shield_timer-=50
						shake(30,0.3)
						add_explosion_eff(v.x,v.y,v.sx,v.sy)
						-- sfx(3,3)
					else _ship:kill() end
					del(self.particles,v)
				end
			end

		elseif v.type=="explosion" then
			circ(v.x,v.y,ptcl_size_explosion[v.age]*v.size,cc)
			v.x+=v.sx+rnd(1)-0.5
			v.y+=v.sy+rnd(1)-0.5
			v.sx*=0.9
			v.sy*=0.9
			if(v.age>18) del(self.particles,v)

		elseif v.type=="explosion_dust" then
			pset(v.x,v.y,cc)
			v.x+=v.sx
			v.y+=v.sy
			v.sx*=0.94
			v.sy*=0.94
			if(v.age>30) del(self.particles,v)

		elseif v.type=="hit" then
			pset(v.x,v.y,cc)
			v.x+=v.sx
			v.y+=v.sy
			v.sx*=0.94
			v.sy*=0.94
			if(v.age>12) del(self.particles,v)

		elseif v.type=="line" then
			line(v.x+v.x1,v.y+v.y1,v.x+v.x2,v.y+v.y2,cc)
			local p1,p2=rotate(v.x1,v.y1,v.r,{x=0.99,y=0.98}),rotate(v.x2,v.y2,v.r,{x=0.98,y=0.99})
			v.x+=v.sx
			v.y+=v.sy
			v.x1=p1.x
			v.y1=p1.y
			v.x2=p2.x
			v.y2=p2.y
			v.r*=0.99
			v.sx*=0.99
			v.sy*=0.99
			if(v.age>v.age_max) del(self.particles,v)

		elseif v.type=="circle" then
			local r=v.r1+(v.r2-v.r1)*(v.age/v.age_max)
			circ(v.x,v.y,r,cc)
			if(v.age>v.age_max) del(self.particles,v)

		elseif v.type=="bonus" then
			-- local x=min(3,-16-sin((120-v.age)/240)*20)
			local dr=clamp((1-abs(1-v.age/90))*1.5,0,1) -- 0->1->delay->0
			-- print79("bonus!!!",3,16,cc,0,false,dr)
			print57("bonus!!!",3,16,cc,0,dr)
			if(v.age>180) del(self.particles,v)

		elseif v.type=="debug_line" then
			local c=6+v.x1%6
			line(v.x1,v.y1,v.x2,v.y2,c)
			circfill(v.x1,v.y1,1,c)
			if(v.age>60) del(self.particles,v)

		end
		v.age+=1
	end
end

function space:on_update()
end




-- <ship> ----------------------------------------
ship=class(sprite)
function ship:init()
	self.x=sw/2
	self.y=sh/2
	self.spd=0
	self.spd_x=0
	self.spd_y=0
	self.spd_max=1.5
	self.angle=0
	self.angle_acc=0
	self.angle_acc_power=0.0009
	self.thrust=0
	self.thrust_acc=0
	self.thrust_power=0.0009
	self.thrust_max=1.0
	self.tail={x=0,y=0}
	self.tail2={x=0,y=0}
	self.head={x=0,y=0}
	self.fire_spd=2.5
	self.bullet_remain=5
	self.bullet_remain_max=5
	self.fire_intv=8
	self.fire_intv_full=8
	self.fire_intv_max=30
	
	self.use_shield=false
	self.shield_enable=true
	self.shield_timer=200
	self.shield_timer_max=200
	
	self.is_killed=false
	
	-- self:on("update",self.on_update) -- stage:emit_update()가 동작 안해서 꺼놨음
	self.__on_killed=false
	self.__show=true
end

function ship:set_mode(n)
	-- mode1: default
	-- mode2: super power!
	if n==2 then
		self.fire_intv=6
		self.fire_intv_full=6
		self.fire_intv_max=6
	else
		self.fire_intv=8
		self.fire_intv_full=8
		self.fire_intv_max=30
	end
end

function ship:_draw()

	self:on_update()
	if(self.__on_killed) self:on_killed()

	if(not self.__show) return

	local x,y=self.x,self.y
	local x0=cos(self.angle)
	local y0=sin(self.angle)
	self.tail.x=x-x0*5
	self.tail.y=y-y0*5
	self.tail2.x=x-x0*12
	self.tail2.y=y-y0*12
	self.head.x=x+x0*8
	self.head.y=y+y0*8
	self:draw_ship(x,y)
	-- pset(self.tail.x,self.tail.y,cc)

	-- 변두리에 있을 때 맞은편에도 그림
	if x<4 then self:draw_ship(x+sw+2,y) end
	if y<4 then self:draw_ship(x,y+sh+2) end
	if x>123 then self:draw_ship(x-sw-2,y) end
	if y>123 then self:draw_ship(x,y-sh-2) end
end

function ship:draw_ship(x,y)
	draw_shape(s_ship,x,y,cc,self.angle)
	
	if self.thrust_acc>0.001 and f%3==0 then
		local s={x=0.3+sin(t()*5)*0.2+self.thrust_acc*160,y=1}
		draw_shape(s_thrust,self.tail.x,self.tail.y,cc,self.angle,false,1,s)
	end

	if self.use_shield then
		local r=self.shield_timer/self.shield_timer_max
		-- draw_shape(s_shield,x,y,cc,-f%30/30,false,r)
		draw_shape(s_shield,x,y,cc,t()%0.5/0.5,false,r)
	end

	if self.shield_enable==false and t()%0.25<0.1 then
		draw_shape_dot(s_shield,x,y,cc,t()%3/3)
	end
end

function ship:on_update()

	-- if not self.draw then return end
	if not self.__show then return end

	-- rotation
	if btn(0) then self.angle_acc+=self.angle_acc_power
	elseif btn(1) then self.angle_acc-=self.angle_acc_power end
	local a=self.angle+self.angle_acc
	self.angle=a>1 and a-1 or a<0 and a+1 or a
	self.angle_acc*=0.93
	if(abs(self.angle_acc)<0.0005) self.angle_acc=0

	-- acceleration
	if btn(2) then
		self.thrust_acc+=self.thrust_power
	end
	self.thrust=clamp(self.thrust+self.thrust_acc,-self.thrust_max,self.thrust_max)
	self.thrust_acc*=0.8
	self.thrust*=0.9
	local thr_x=cos(self.angle)*self.thrust
	local thr_y=sin(self.angle)*self.thrust
	self.spd_x+=thr_x
	self.spd_y+=thr_y
	self.spd_x*=0.997
	self.spd_y*=0.997

	-- local tx=self.x+self.spd_x
	-- local ty=self.y+self.spd_y
	-- self.x=tx>131 and tx-131 or tx<-4 and tx+131 or tx
	-- self.y=ty>131 and ty-131 or ty<-4 and ty+131 or ty
	self.x+=self.spd_x
	self.y+=self.spd_y
	coord_loop(self)

	-- fire
	self.fire_intv-=1
	if self.fire_intv<-self.fire_intv_max then
		self.fire_intv=0
		self.bullet_remain=self.bullet_remain_max
	end

	if btn(4) and self.fire_intv<=0 then

		if(dev) score_up(4)

		-- sfx(23,-1)

		-- self.fire_intv=self.fire_intv_full
		if self.bullet_remain<=1 then
			self.fire_intv=self.fire_intv_max
			self.bullet_remain=self.bullet_remain_max
		else
			self.bullet_remain-=1
			self.fire_intv=self.fire_intv_full
		end

		local a=self.angle+rnd()*0.02-0.01
		local fire_spd_x=cos(a)*self.fire_spd+self.spd_x*1.4
		local fire_spd_y=sin(a)*self.fire_spd+self.spd_y*1.4
		add(_space.particles,
		{
			type="bullet",
			x=self.head.x,
			y=self.head.y,
			sx=fire_spd_x,
			sy=fire_spd_y,
			age_max=80,
			age=1
		})
	end

	-- shield
	if(self.shield_timer<=0) self.shield_enable=false self.shield_timer=max(self.shield_timer,0)
	if btn(5) and self.shield_timer>0 and self.shield_enable then
		self.use_shield=true
		self.shield_timer-=1
	else
		self.use_shield=false
		if self.shield_enable then
			if(self.shield_timer<self.shield_timer_max) self.shield_timer+=0.5
		else
			self.shield_timer+=0.3
			if(self.shield_timer>=self.shield_timer_max) self.shield_enable=true
		end
	end

	-- add effect
	if self.thrust_acc>0.001 then
		-- sfx(4,2)
		-- add(_space.particles,
		-- {
		-- 	type="thrust",
		-- 	x=self.tail.x-1+rnd(2),
		-- 	y=self.tail.y-1+rnd(2),
		-- 	sx=-thr_x*130,
		-- 	sy=-thr_y*130,
		-- 	age=1
		-- })
	else
		-- sfx(-1,2)
	end

	-- speed limit
	local spd=sqrt(self.spd_x^2+self.spd_y^2)
	if spd>self.spd_max then
		local r=self.spd_max/spd
		self.spd_x*=r
		self.spd_y*=r
	end

	-- hit test with enemies
	
	-- for i,e in pairs(_enemies.list) do
	local x,y=self.x,self.y
	for e in all(_enemies.list) do
		local dist=(e.size==4) and 12 or (e.size==1) and 13 or (e.size==2) and 10 or 7
		if(self.use_shield) dist+=4
		if abs(e.x-x)<=dist and abs(e.y-y)<=dist and get_dist(e.x,e.y,x,y)<=dist then	
			if self.use_shield then
				self.shield_timer-=50
				shake(30,0.3)
				-- 충돌 방향만 보고 서로 반대로 밀기
				local d=atan2(e.x-x,e.y-y)
				local sx,sy=cos(d)*0.35,sin(d)*0.35
				e.spd_x=sx
				e.spd_y=sy
				e.x+=sx*2
				e.y+=sy*2
				self.spd_x=-sx
				self.spd_y=-sy
				self.x-=sx*2
				self.y-=sy*2
				-- sfx(2,3)
				add_hit_eff((x+e.x)/2,(y+e.y)/2,d)
			elseif not self.is_killed then
				self:kill()
			end
		end
	end
end

function ship:kill()
	if(self.is_killed) return

	-- sfx(3,3)
	-- sfx(-1,2) -- 분사음 강제로 끔
	local x,y=self.x,self.y
	add_explosion_eff(x,y,self.spd_x,self.spd_y,2,40)
	add_break_eff(x,y,s_ship,1,60)
	add_break_eff(x,y,s_ship,2,60)

	self.is_killed=true
	-- self:show(false)
	self.__show=false
	self.revive_count=150
	
	-- self:on("update",self.on_killed)
	self.__on_killed=true

	shake()
end

function ship:on_killed()
	self.revive_count-=1
	if(self.revive_count==60 and gg.ships>=1) add_circle_eff(sw/2,sh/2,4,80,60)
	if self.revive_count<=0 then
		gg.ships-=1
		if gg.ships>=0 then
			add_break_eff(sw/2,sh/2,s_circle,0.8,20,true)
			self:revive()
		else
			_enemies:kill_all()
			gg.is_gameover=true
			gg.gameover_timer=0
			gg.scene_timer=0
			gg.key_wait=240
			shake()
		end
		-- self:remove_handler("update",self.on_killed)
		self.__on_killed=false
	end
end

function ship:reset()
	self.x,self.y=sw/2,sh/2
	self.spd=0
	self.spd_x,self.spd_y=0,0
	self.angle=0
	self.angle_acc=0
	self.thrust=0
	self.thrust_acc=0
	self.is_killed=false
	self.shield_enable=true
	self.shield_timer=self.shield_timer_max
end

function ship:revive()
	_enemies:kill_center(85)
	self:reset()
	-- self:show(true)
	self.__show=true
	add_explosion_eff(sw/2,sh/2,0,0,2,40)
end







-- <enemies> ----------------------------------------
enemies=class(sprite)
function enemies:init()
	self.list={}
end

function enemies:group_update() -- 소행성 수를 일정하게 맞춰준다
	if gg.is_gameover then return end
	-- srand(f%101)

	local c1,c2,c3,c4=0,0,0,0
	for e in all(self.list) do
		if(e.size==1) c1+=1
		if(e.size==4) c4+=1
	end

	-- 난이도 2만점마다 증가(큰 소행성이 리필되는 수 6~40)
	local df=min(40,6+gg.score1\2000+gg.score2*5)
	-- 카이퍼 벨트 모드라면 최소 수량을 더 늘린다
	if(gg.title_selected_menu==2) df=40
	
	if c1<df and #self.list<8+df then
		local r=rnd()
		local x=cos(r)*sw*0.7
		local y=sin(r)*sh*0.7
		local sx,sy=get_base_spd(atan2(-x,-y)) -- 화면 중앙을 향하는 속도
		-- self:add(sw/2+x,sh/2+y,1,-x*0.001,-y*0.001,true)
		self:add(sw/2+x,sh/2+y,1,sx,sy,true)
	end

	-- 20000점마다 UFO 출현 + 게임 속도 빨라짐
	if c4<1 and gg.score1\2000+gg.score2*5>gg.ufo_born then 
		local sx=min(1,0.4*gg.spd_multiplier)
		self:add(-3,sh/2+rndi(100)-50,4,sx,0,true)
		if(gg.ufo_born>20) self:add(sw+3,sh/2+rndi(100)-50,4,-sx,0,true) -- 후반에는 양쪽에서 동시 출현
		gg.ufo_born+=1
		gg.spd_multiplier+=0.1
	end

end

function enemies:_draw()
	
	if(f%67==0) self:group_update() -- 주기적으로 소행성 수량 조절
	
	for i,e in pairs(self.list) do
		e.x+=e.spd_x
		e.y+=e.spd_y
		e.angle=angle_loop(e.angle+e.spd_r,0,1)
		
		if e.is_yeanling then
			if(e.x>5 and e.x<sw-6 and e.y>5 and e.y<sh-6) e.is_yeanling=false
		else
			if e.size==4 then -- UFO는 화면 좌우 밖으로 나가면 사라짐
				if(e.x>sw+2 or e.x<-2) del(self.list,e)
			end
			coord_loop(e)
		end

		if e.size==4 then
			-- circ(e.x,e.y,8,27) -- 크기 확인용
			do
				draw_shape(s_ufo,e.x,e.y,cc)
				local d=(f/12%6)*1.8
				line(e.x-5+d,e.y-1,e.x-7+d*1.4,e.y+1,cc)
				d=((f/12+3)%6)*1.8
				line(e.x-5+d,e.y-1,e.x-7+d*1.4,e.y+1,cc)
			end

			if(e.type==1) e.spd_y=e.spd_x*sin(e.x%200/200) -- UFO 타입1은 지그재그 운행
			e.count+=1
			-- ufo가 새로 나올 때마다 총알 인터벌이 점점 짧아짐
			if e.count>=max(30,100-gg.ufo_born*5) and not _ship.is_killed then
				-- sfx(24,1)
				e.count=0
				-- sfx(23,-1)
				local angle=atan2(_ship.x-e.x+rnd(10)-5,_ship.y-e.y+rnd(10)-5)
				local sx=cos(angle+rnd()*0.04)
				local sy=sin(angle+rnd()*0.04)
				add(_space.particles,
				{
					type="bullet_ufo",
					x=e.x+sx*9,
					y=e.y+sy*9,
					sx=sx*min(2,gg.spd_multiplier),
					sy=sy*min(2,gg.spd_multiplier),
					age_max=300,
					age=1
				})
			end
		else
			-- 크기 테스트
			-- local r=(e.size==4) and 7 or (e.size==1) and 11 or (e.size==2) and 8 or 5
			-- circ(e.x,e.y,r,27)
			
			draw_shape(e.shape,e.x,e.y,cc,e.angle)

			-- 변두리에 있을 때 맞은편에도 그림(생성 초기는 제외)
			if not e.is_yeanling then
				if e.x<4 then draw_shape(e.shape,e.x+sw+2,e.y,cc,e.angle) end
				if e.y<4 then draw_shape(e.shape,e.x,e.y+sh+2,cc,e.angle) end
				if e.x>sw-5 then draw_shape(e.shape,e.x-sw-2,e.y,cc,e.angle) end
				if e.y>sh-5 then draw_shape(e.shape,e.x,e.y-sh-2,cc,e.angle) end
			end
		end
	end

end

function get_base_spd(r)
	local spd_base=(0.1+rnd(0.3))*min(2,gg.spd_multiplier)
	local r=r and r or rnd()
	return cos(r)*spd_base,sin(r)*spd_base
end

function enemies:add(x,y,size,spd_x,spd_y,yeanling) -- size=1(big)~3(small),4(ufo)
	local sx,sy,sr,sp=spd_x,spd_y,0,s_ufo
	if size<4 then
		-- if(sx==nil) sx=(0.2+rnd(0.3))*(rndi(2)-0.5)
		-- if(sy==nil) sy=(0.2+rnd(0.3))*(rndi(2)-0.5)
		if sx==nil then
			-- local spd_base=(0.2+rnd(0.3))*min(2,gg.spd_multiplier)
			-- sx=spd_base*(rndi(2)-0.5)
			-- sy=spd_base*(rndi(2)-0.5)
			sx,sy=get_base_spd()
		end
		sr=(0.5+rnd(1))*(rndi(2)-0.5)*0.01
		-- sp=(size==1) and s_ast10 or (size==2) and s_ast20 or s_ast30
		-- if(#self.list%2<1) sp=(size==1) and s_ast11 or (size==2) and s_ast21 or s_ast31
		sp=(size==1) and s_ast1[1+rndi(#s_ast1)] or (size==2) and s_ast2[1+rndi(#s_ast2)] or s_ast3[1+rndi(#s_ast3)]
	end
	local e={
		is_yeanling=yeanling,
		x=x,
		y=y,
		angle=rnd(),
		spd_x=sx,
		spd_y=sy,
		spd_r=sr,
		size=size,
		shape=sp,
		count=0,
	}
	if size==4 then
		e.type=gg.ufo_born%3
		if(e.type>0) e.spd_y=e.spd_x
	end
	add(self.list,e)
end

function enemies:kill_all()
	for e in all(self.list) do
		-- add_break_eff(e.x,e.y,s_ast2[1],3,60,true)
		add_break_eff(e.x,e.y,e.shape,3,60,true)
	end
	-- sfx(3,3)
	self.list={}
end

function enemies:kill_center(r)
	-- local cx,cy=sw/2,sh/2
	for e in all(self.list) do
		if abs(cx-e.x)<=r and abs(cy-e.y)<=r and get_dist(cx,cy,e.x,e.y)<=r then
			del(self.list,e)
			-- add_break_eff(e.x,e.y,s_ast2[1])
			add_break_eff(e.x,e.y,e.shape)
			-- sfx(3,3)
		end
	end
end





-- <title> ----------------------------------------
title=class(sprite)
function title:init()
	self.menu_str={"original mode","kuiper belt mode","ufo rush mode"}
	self.modal_timer=0
	self:show(true)
end
function title:_draw()
	-- local x,y=self.tx,self.ty
	if gg.is_title then
		if(gg.title_timer<300) gg.title_timer+=1
		local x,y=sw/2,sh/2-52

		-- dev_draw_guide(sw/2,sh/2)

		local dy1=sin(t()%3/3)*8
		local dy2=sin((t()-0.4)%3/3)*8
		local dy3=sin((t()-0.8)%4/4)*6
		local dx1=sin((t())%4/4)*5
		local dx2=sin((t()-0.3)%4/4)*9
		local dx3=sin((t()-0.6)%4/4)*6
		local s=1+(1-gg.title_timer/300)^4/2
		local dr=get_draw_ratio(gg.title_timer,-0.5,2,240) -- -0.5->2 / 240frames
		draw_shape(s_title,x+dx1,y+dy1,cc,0,false,dr,{x=s,y=s})
		draw_shape(s_demake,x-50+dx2,y+36+dy2,cc,0,false,dr-0.4,{x=s,y=s})
		draw_shape(s_2023,x+76+dx3,y+36+dy3,cc,0,false,dr-0.8,{x=s,y=s})
		-- draw_shape(s_debris[3],sw-90+dx3,sh-60+dy3,cc,0.01,false,dr-1,{x=1,y=1}) -- 고양이
		draw_shape(s_lunarlander,sw-60+dx3,sh-120+dy3,cc,0,false,dr-1) -- 달착륙선
		
		local dy4=sin(t()%5/5)*7
		local dy5=sin((t()-0.3)%5/5)*7
		local dy6=sin((t()-0.6)%5/5)*7
		local dx4=sin(t()%6/6)*7
		local dx5=sin(t()%5/5)*7
		local dx6=sin(t()%4/4)*7
		
		-- draw menu
		menu_str={}
		for i=1,#self.menu_str do
			local t1,t2="",""
			if i==gg.title_selected_menu then
				t1,t2="> "," <"
				if(t()%0.3<0.15) t1,t2="- "," -"
			end
			menu_str[i]=t1..self.menu_str[i]..t2
		end
		local dr=get_draw_ratio(gg.title_timer,-3,3,240) -- -3->3 / 240frames
		-- print79(menu_str[1],sw/2+dx4,sh/2+30+dy4,cc,0.5,false,dr,gg.title_selected_menu==1)
		-- print79(menu_str[2],sw/2+dx5,sh/2+50+dy5,cc,0.5,false,dr-0.7,gg.title_selected_menu==2)
		-- print79(menu_str[3],sw/2+dx6,sh/2+70+dy6,cc,0.5,false,dr-1.4,gg.title_selected_menu==3 and self.modal_timer<=0)
		print57(menu_str[1],sw/2+dx4,sh/2+30+dy4,cc,0.5,dr,gg.title_selected_menu==1)
		print57(menu_str[2],sw/2+dx5,sh/2+50+dy5,cc,0.5,dr-0.7,gg.title_selected_menu==2)
		print57(menu_str[3],sw/2+dx6,sh/2+70+dy6,cc,0.5,dr-1.4,gg.title_selected_menu==3 and self.modal_timer<=0)
		
		-- z/x key guide
		do
			
		end

		-- bottom text
		local dy7=sin((t())%5/5)*6
		local dr=get_draw_ratio(gg.title_timer,-2,1,300) -- -2->1 / 300frames
		-- print79("(c)1979 atari inc. demaked by @mooon",sw/2-dx1,sh-16+dy7,cc,0.5,false,dr)
		-- print79("version "..ver,sw-4,4,cc,1,false,dr)
		print57("(c)1979 atari inc. demaked by @mooon",sw/2-dx1,sh-16+dy7,cc,0.5,dr)
		print57("version "..ver,sw-4,4,cc,1,dr)


		-- draw modal window
		if self.modal_timer>0 then
			local dr=1-get_draw_ratio(self.modal_timer-210,0,1,30)^4 -- 0->1
			local cx,cy=cx+dy4,cy+dx4
			local w,h=260+dr*20,40+dr*20
			paltron(cc,32,cc-7)
			paltron(cc-5,32,cc-7)
			paltron(cc-7,32,cc-7)
			rectfill(cx-w/2,cy-h/2,cx+w/2,cy+h/2,32)
			draw_shape(s_box,cx-w/2,cy,cc,0,false,1,{x=w/10,y=h/10})
			dr=get_draw_ratio(240-self.modal_timer,0,1,90)

			if gg.title_selected_menu==4 then -- z/x key guide
				local x,y=cx-74,cy-14
				-- print79("z",x,y,cc,0,false,1,true)
				-- print79("fire",x+16,y,cc)
				-- print79("x",x,y+21,cc,0,false,1,true)
				-- print79("shield",x+16,y+22,cc)
				-- print79("^",x+89,y,cc,0,false,1,true)
				-- print79("thrust",x+113,y,cc)
				-- print79("<",x+80,y+22,cc,0,false,1,true)
				-- print79(">",x+98,y+22,cc,0,false,1,true)
				-- print79("rotate",x+113,y+22,cc)
				print57("z",x,y,cc,0,1,true)
				print57("fire",x+16,y,cc)
				print57("x",x,y+21,cc,0,1,true)
				print57("shield",x+16,y+22,cc)
				print57("^",x+89,y,cc,0,1,true)
				print57("thrust",x+113,y,cc)
				print57("<",x+80,y+22,cc,0,1,true)
				print57(">",x+98,y+22,cc,0,1,true)
				print57("rotate",x+113,y+22,cc)
			elseif gg.title_selected_menu==3 then -- ufo rush mode
				-- print79("sorry, under develpment...",cx,cy-3,cc,0.5,false,dr)
				print57("sorry, under develpment...",cx,cy-3,cc,0.5,dr)
			end
			if self.modal_timer==1 then
				add_break_eff(cx-54,cy,s_demake,3,30,true)
				add_break_eff(cx+80,cy,s_2023,3,30,true)
				shake(30,0.3)
			end
		end
		
		-- 키 입력
		if gg.key_wait>0 then
			gg.key_wait-=1
		elseif self.modal_timer>0 then
			self.modal_timer-=1
		elseif btn(2) then gg.title_selected_menu=value_loop(gg.title_selected_menu-1,1,3) gg.key_wait=10
		elseif btn(3) then gg.title_selected_menu=value_loop(gg.title_selected_menu+1,1,3) gg.key_wait=10
		elseif (btn(4) or btn(5)) then
			-- sfx(6,3)
			if gg.title_selected_menu==3 then
				self.modal_timer=240
			else
				add_break_eff(x,y,s_title,3.5,50,true)
				add_break_eff(x-50,y+36,s_demake,3.5,50,true)
				add_break_eff(x+76,y+36,s_2023,3.5,50,true)
				add_break_eff(sw/2-30,sh/2+30,s_text_break,3,30,true)
				add_break_eff(sw/2-30,sh/2+50,s_text_break,3,30,true)
				add_break_eff(sw/2-30,sh/2+70,s_text_break,3,30,true)
				add_break_eff(sw/2-128,sh-11,s_text_break,3,30,true)
				add_break_eff(sw/2-64,sh-11,s_text_break,3,30,true)
				add_break_eff(sw/2,sh-11,s_text_break,3,30,true)
				add_break_eff(sw/2+64,sh-11,s_text_break,3,30,true)

				gg.is_title=false
				if gg.title_selected_menu==2 then
					gg.spd_multiplier=5
				end
				-- set_menu()
				_ship:reset()
				_ship:set_mode(gg.title_selected_menu==2 and 2 or 1)
				_ship:show(true)
				_ship.__show=true
				_enemies:show(true)
				
				shake(30,0.3)

				-- 데모 플레이 반복할 때 같은 상황이 연출되게끔 여기서 리셋
				f=0
				-- srand(0)
			end
		end

	elseif gg.is_gameover then
		if(gg.gameover_timer<300) gg.gameover_timer+=1
		-- dev_draw_guide(sw/2,sh/2)

		local x,y=sw/2,sh/2-52
		local dy1=sin(t()%3/3)*7
		local dy2=cos(t()%3/3)*7
		local dx1=sin((t())%4/4)*5
		local dx2=sin((t()-0.3)%4/4)*9
		local dr=get_draw_ratio(gg.gameover_timer,-0.5,2,180) -- -0.5->2 / 180
		draw_shape(s_game,sw/2-86+dx1,y+dy1,cc,0,false,dr)
		draw_shape(s_over,sw/2+8+dx2,y+dy2,cc,0,false,dr-1)

		local dy3=sin(t()%4/4)*6
		local dx3=sin((t()-0.6)%4/4)*6
		dr=get_draw_ratio(gg.gameover_timer,-2,2,240) -- -1->1 / 240f
		-- print79(self.menu_str[gg.title_selected_menu].." score",sw/2+dx3,y+50+dy3,cc,0.5,false,dr)
		print57(self.menu_str[gg.title_selected_menu].." score",sw/2+dx3,y+50+dy3,cc,0.5,dr)
		print_score(sw/2+dx2+dx3,y+64+dy3*1.3,1.6,8,dr)

		local dy4=sin(t()%5/5)*6
		local dx4=sin(t()%6/6)*7
		dr=get_draw_ratio(gg.gameover_timer,-2,1,300) -- -2->1 / 300f
		local t=(gg.gameover_timer>=300 and t()%1<0.5) and "" or "press z/x key to continue"
		-- print79(t,sw/2+dx4,y+120+dy4,cc,0.5,false,dr)
		print57(t,sw/2+dx4,y+120+dy4,cc,0.5,dr)

		_ship:show(false)
		_ship.__show=false
		_enemies:show(false)

		if gg.key_wait>0 then
			gg.key_wait-=1
		elseif btn(4) or btn(5) then
			-- sfx(3,3)
			shake(30,0.3)
			add_break_eff(sw/2-86,y,s_game,3,50,true)
			add_break_eff(sw/2+8,y,s_over,3,50,true)
			add_break_eff(sw/2-32,y+42,s_text_break,3,30,true)
			add_break_eff(sw/2-32,y+56,s_text_break,3,30,true)
			add_break_eff(sw/2-52,y+68,s_text_break,3,30,true)
			add_break_eff(sw/2-84,sh/2+66,s_text_break,3,30,true)
			add_break_eff(sw/2+10,sh/2+66,s_text_break,3,30,true)

			gg_reset()
		end
	end
end







-- <etc. functions> ----------------------------------------

function draw_cross_pattern()
	local function draw_cross(x,y,n)
		local w=10
		if((f+n)%5==0) line(x-w/2,y,x+w/2,y,cc)
		if((f+n)%5==4) line(x,y-w/2,x,y+w/2,cc)
	end
	for i=1,7 do
		for j=1,4 do
			draw_cross(((sw+50)/8)*i-25,((sh+50)/5)*j-25,i+j)
		end
	end
end

function draw_color_table()
	local size=26
	for i=0,31 do
		local x=i%16*size
		local y=i\16*size
		rectfill(x,y,x+size,y+size,i)
		-- print79(tostr(i),x+2,y+2,value_loop(i-10,0,31))
		print57(tostr(i),x+2,y+2,value_loop(i-10,0,31))
	end
end

-- c1을 c2가 덮으면 c3으로 바꿔준다
function paltron(c1,c2,c3)
	poke(0x8000+c1+(c2*64),c3)
end

-- v가 0->dur까지 증가하는동안 min->max로 증가하는 ratio를 반환
function get_draw_ratio(v,min,max,dur)
	return clamp(max-(1-v/dur)*(max-min),min,max)
end

function dev_draw_guide(x,y)
	if(x==nil) x,y=sw/2,sh/2
	for i=1,10 do
		local dx=i*20
		local dy=i*16
		rect(x-dx,y-dy,x+dx,y+dy,5)
	end
end

function get_wave_str(str)
	local str2=""
	for i=1,#str do
		if i==flr(f%60/3) then
			str2=str2.."\|f"..str[i].."\|h"
		elseif i==flr((f+6)%60/3) then
				str2=str2.."\|h"..str[i].."\|f"
		else
			str2=str2..str[i]
		end
	end
	return str2
end

function score_up(size)

	-- 원래는 소행성 크기별로 20,50,100점인데 좀 뻥튀기 함
	if size==4 then gg.score1+=300
	elseif size==3 then gg.score1+=50
	elseif size==2 then gg.score1+=20
	elseif size==1 then gg.score1+=8
	end

	if gg.score1>=10000 then
		gg.score2=min(gg.score2+1,10000)
		gg.score1-=10000
	end

	-- 5만점마다 보너스(가득차서 못 받는 경우는 그냥 넘어감)
	if gg.score1\5000+gg.score2*2>gg.bonus_earned then
		if(gg.ships<gg.ships_max) add(_space.particles,{type="bonus",age=0})
		gg.ships=min(gg.ships+1,gg.ships_max)
		gg.bonus_earned+=1
		-- sfx(25,1)
		-- if(gg.ships<=gg.ships_max) add(_space.particles,{type="bonus",age=0})
	end

end

function value_loop(v,min,max) -- (4,1,3) -> 1 / (0,1,3) -> 3 / (-2,0,8) -> 6
	-- return v<min and max or v>max and min or v
	return v<min and max-(min-v)+1 or v>max and min+(v-max)-1 or v
end

function angle_loop(v,min,max) -- (1.15,0,1) -> 0.15 / (0.4,0.5,2) -> 1.9
  if v<min then v=(v-min)%(max-min)+min
  elseif v>max then v=v%max+min end
  return v
end

function coord_loop(a)
	local x,y=a.x,a.y
	x=x>sw+3 and x-sw-3 or x<-4 and x+sw+3 or x
	y=y>sh+3 and y-sh-3 or y<-4 and y+sh+3 or y
	a.x=x a.y=y
end

function rotate(x,y,r,scale)
	if(scale) x,y=x*scale.x,y*scale.y
	if(not r or r==0) return {x=x,y=y}
	local cosv=cos(r)
	local sinv=sin(r)
	local p={}
	p.x=cosv*x-sinv*y
	p.y=sinv*x+cosv*y	
	return p
end

function draw_shape_dot(arr,x,y,c,angle)
	local p1
	for i=1,#arr,2 do
		if arr[i]=="x" then
			p1={x="x",y="x"}
		else
			p1=rotate(arr[i],arr[i+1],angle,scale)
			pset(p1.x+x,p1.y+y,c)
		end
	end
end

function draw_shape(arr,x,y,c,angle,with_wave,draw_ratio,scale)
	local p1=rotate(arr[1],arr[2],angle,scale)
	local i2=#arr-1
	if draw_ratio then
		if(draw_ratio<=0) return nil
		draw_ratio=clamp(draw_ratio,0,1)
		local lines=#arr/2-1
		local draw_lines=flr(lines*draw_ratio)+1
		i2=min(2+draw_lines*2,#arr-1)
	else draw_ratio=1 end
	for i=3,i2,2 do
		if arr[i]=="x" then
			p1={x="x",y="x"}
		else
			local p2=rotate(arr[i],arr[i+1],angle,scale)

			-- draw_ratio에 맞춰서 선 하나 길이까지 정밀하게 그리기
			if draw_ratio<1 and i>=i2-1 and p1.x!="x" and p2.x!="x" then
				local lines=#arr/2-1
				local ratio_per_line=1/lines
				local current_ratio=(draw_ratio%ratio_per_line)/ratio_per_line
				local px=p1.x+(p2.x-p1.x)*current_ratio
				local py=p1.y+(p2.y-p1.y)*current_ratio
				p2={x=px,y=py}
			end

			if p1.x!="x" then
				if with_wave then
					local dy1=sin((p1.x+p1.y-t()*60)%80/80)*3
					local dy2=sin((p2.x+p2.y-t()*60)%80/80)*3
					line(p1.x+x,p1.y+y+dy1,p2.x+x,p2.y+y+dy2,c)
				else
					line(p1.x+x,p1.y+y,p2.x+x,p2.y+y,c)
				end
			end
			p1=p2
		end
	end
	if draw_ratio<1 and p1.x!="x" then
		circfill(p1.x+x,p1.y+y,1,c)
	end
	-- if(dev) circ(x,y,2,14) -- pivot center circle
end

function get_dist(x1,y1,x2,y2)
	return sqrt((x2-x1)^2+(y2-y1)^2)
end

function add_debugline_eff(x1,y1,x2,y2)
	add(_space.particles,
		{
			type="debug_line",
			x1=x1,y1=y1,x2=x2,y2=y2,age=0
		})
end
function add_circle_eff(x,y,r_from,r_to,timer)
	add(_space.particles,
		{
			type="circle",
			x=x,
			y=y,
			r1=r_from,
			r2=r_to,
			age=0,
			age_max=timer
		})
end
function add_explosion_eff(x,y,spd_x,spd_y,power,count)
	local c=count or 12
	local p=power or 1
	for i=1,c do
		local sx=cos(i/c+rnd()*0.1)*p
		local sy=sin(i/c+rnd()*0.1)*p
		add(_space.particles,
		{
			type="explosion_dust",
			x=x+rnd(2)-1,
			y=y+rnd(2)-1,
			sx=sx*(0.2+rnd(2))+spd_x*p*0.7,
			sy=sy*(0.2+rnd(2))+spd_y*p*0.7,
			age=1+rndi(8)
		})
	end
end
function add_hit_eff(x,y,angle)
	for i=1,8 do
		local a=angle+flr(i/8+0.5)*0.6-0.3
		local sx=cos(a)
		local sy=sin(a)
		add(_space.particles,
		{
			type="hit",
			x=x+rnd(4)-2,
			y=y+rnd(4)-2,
			sx=sx*(0.7+rnd()*2),
			sy=sy*(0.7+rnd()*2),
			age=1+rndi(6)
		})
	end
end
function add_break_eff(x0,y0,arr,pow,age,with_dust)
	local pow=pow or 1.5
	local age=age or 10
	local p1={x=arr[1],y=arr[2]}
	for i=3,#arr-1,2 do
		if arr[i]=="x" then
			p1={x="x",y="x"}
		else
			local p2={x=arr[i],y=arr[i+1]}
			if p1.x!="x" then
				local x1,y1,x2,y2=p1.x,p1.y,p2.x,p2.y
				local dx,dy=(x2-x1)/2,(y2-y1)/2
				local v={
					type="line",
					x=x0+x1+dx,y=y0+y1+dy,
					x1=-dx,y1=-dy,
					x2=x2-x1-dx,y2=y2-y1-dy,
					sx=(rnd()-0.5)*pow,sy=(rnd()-0.5)*pow,
					r=(0.1+rnd())*0.02*(rndi(2)-0.5)*pow,
					age=0,age_max=age+rndi(age)
				}
				add(_space.particles,v)
				if with_dust then
					local r=rnd()
					local spd=3+rnd(6)
					local sx,sy=cos(r)*spd,sin(r)*spd
					add(_space.particles,
					{
						type="explosion_dust",
						x=x0+x1+dx,y=y0+y1+dy,sx=sx,sy=sy,
						age=-rndi(age*0.4)
					})
				end
			end
			p1=p2
		end
	end
end

function shake_diff()
	return stage.__on_shake and (rnd(12)-6)*shake_t/100 or 0 -- +-6 -> 0
end

function print_score(x,y,scale,max_len,draw_ratio)
	local t1=get_score_str()
	local len=max_len or #t1
	for i=1,len-#t1 do t1="_"..t1 end

	if draw_ratio then
		draw_ratio=clamp(draw_ratio,0,1)
		len=flr(#t1*draw_ratio)
		t1=sub(t1,1,len)
	end
	
	local s=scale or 1
	local nw,gap=6*s,3*s
	local lx=x-(len*(nw+gap)-gap)/2

	-- 전투기가 점수 밑에 들어가면 망점 처리
	-- if not _ship.is_killed and _ship.y<20 and _ship.x<sw/2+50 and _ship.x>sw/2-50 then
	-- 	for i=0,7 do poke(0x5500+i,i%2==0 and 85 or 170) end -- fill pattern
	-- end

	

	for i=1,#t1 do
		local n=sub(t1,i,i)
		local x2=lx+(i-1)*(nw+gap)+shake_diff()
		local y2=y+shake_diff()
		draw_shape(s_num[n],x2,y2,cc,0,false,1,{x=s,y=s})
	end
	-- fillp()
end

function get_score_str()
	-- 소숫점 덧셈 버그 때문에 정수 2개 사용(0.1+0.1=0.199같은 버그)
	local t=""
	local n1,n2=gg.score1,gg.score2
	if n2>=1000 then t="99999999"
	else
		local t1,t2=tostr(n1),tostr(n2)
		t=n1<=0 and "0" or t1.."0"
		if n2>0 then
			while #t<5 do t="0"..t end
			t=t2..t
		end
	end
	return t
end

function shaking()
	if shake_t>0 then
		local n=0.3+shake_t/10*shake_p
		if(shake_t%2==0) camera(rnd(n)-n/2,rnd(n)-n/2)
		shake_t-=1
	else
		camera(0,0)
		-- stage:remove_handler("update",shaking)
		stage.__on_shake=false
	end
end
function shake(dur,pwr)
	shake_t=dur or 80
	shake_p=pwr or 1
	-- stage:on("update",shaking)
	stage.__on_shake=true
end




-- 임시 달 지형 그려보기
lunar_data={}
for i=1,flr(sw/20+1) do
	lunar_data[i]=50+rnd(40)
end
function draw_lunar()
	local x1,x2=0
	local y1,y2=sh-lunar_data[1]
	for i=2,#lunar_data do
		x2=(i-1)*20
		y2=sh-lunar_data[i]
		for k=0,19 do
			local x3=x1+k
			-- line(x3,y1+(y2-y1)*k/20+0.5,x3,sh,32)
			line(x3,y1+(y2-y1)*k/20+0.5,x3,sh,9+i%5)
		end
		-- line((i-2)*20,y1,(i-1)*20,y2,cc)
		line((i-2)*20,y1,(i-1)*20,y2,10+i%5)
		x1,y1=x2,y2
	end
end

-- 임시 달 지형 그려보기 2탄
planet_data={}
add(planet_data,{0,0,1,2,2,25,8,25,9,0,10,0}) -- 가로 10px 기준으로 깊이를 기록
add(planet_data,{0,0,1,30,3,40,4,42,5,120,6,116,7,60,8,60,9,68,10,100})
add(planet_data,{0,100,5,100,6,80,7,60,9,50,10,18})
add(planet_data,{0,18,3,5,4,11,5,26,6,60,8,56,10,16})
add(planet_data,{0,16,1,-80,6,-80,7,0,8,3,9,29,10,29})
add(planet_data,{0,29,1,34,2,76,4,80,5,90,6,100,8,95,9,110,10,200})
add(planet_data,{0,200,1,205,2,280,3,275,5,230,7,226,8,200,9,200,10,300})
add(planet_data,{0,300,8,300,9,270,10,260})
add(planet_data,{0,260,6,260,7,220,8,216,9,10,10,-20})
add(planet_data,{0,-20,2,-20,3,80,7,80,8,30,9,27,10,0})
add(planet_data,{0,0,7,0,8,10,10,10})
add(planet_data,{0,10,10,10})
add(planet_data,{0,10,9,10,10,-20})
add(planet_data,{0,-20,10,-20})
add(planet_data,{0,-20,1,40,4,40,5,20,10,20})
add(planet_data,{0,20,1,-40,2,-44,3,-120,4,-130,6,-125,7,-120,8,-50,9,-40,10,40})
add(planet_data,{0,40,7,40,8,0,10,0})
-- 행성을 원으로 표현하기 위한 y 보정값
function get_planet_diff_y(x)
	return abs(sw/2-x)^2*0.0003/pp.scale
end
-- 지형의 한 구역 그리기
function draw_planet_part(arr,x,y,w,h,c)
	local x1,y1=flr(x+arr[1]*w/10+0.5),flr(y+arr[2]*h/10+0.5)
	y1+=get_planet_diff_y(x1)

	-- 그리는 폭이 좁으면 시작점-끝점만 그림(LOD)
	local i1=(w<6) and #arr-3 or 3

	for i=i1,#arr-1,2 do
		local x2,y2=flr(x+arr[i]*w/10+0.5),flr(y+arr[i+1]*h/10+0.5)
		y2+=get_planet_diff_y(x2)

		-- 검은 세로줄 그리기(별 가림막)
		for k=x1+1,x2 do
			local y3,y4=y1+(k-x1)/(x2-x1)*(y2-y1)+0.5,sh
			line(k,y3,k,y4,32)
		end

		line(x1,y1,x2,y2,c)
		x1,y1=x2,y2
	end
end
-- 지형 그리기
function draw_planet(base_x,base_y)
	local x,y,w,h=base_x,base_y,pp.scale*10,pp.scale -- w,h는 10이 100%
	if(h<1) h=h*h
	
	-- 스케일이 작으면 그냥 큰 원을 그림
	if pp.scale<0.3 then
		local r=1800*pp.scale
		circfill(sw/2,y+r,r,32)
		circ(sw/2,y+r,r,cc)
	else
		-- planet_data를 반복해서 지형 그림(화면 전체에 꽉 차게)
		local n1=-flr(x/(pp.scale*10))-1
		local n2=flr((sw-x)/(pp.scale*10))
		for i=n1,n2 do
			-- local cc=27+i%5 -- 각 구역을 다른 색으로(TEST)
			draw_planet_part(planet_data[i%#planet_data+1],x+i*w,y,w,h,cc)
		end
	end

	-- 기준선 그리기(해발고도)
	if f%3==0 then
		fillp(clsp2[f%#clsp2+1])
		-- line(0,pp.base_y,sw,pp.base_y,cc) -- 수평
		line(x,0,x,sh,cc) -- 수직

		-- 대형 원을 그려보자(달 전체)
		local r=1800*pp.scale
		circ(sw/2,y+r,r,cc)

		fillp()
	end

	
end





--------------------------------------------
cc=11 -- default color
gg_reset=function() -- game state
	gg={
		key_wait=180,
		is_title=true,
		title_timer=0,
		title_selected_menu=1,
		game_mode=1,
		is_gameover=false,
		gameover_timer=0,
		score1=0,
		score2=0,
		ships=3,
		ships_max=10,
		bonus_earned=0,
		ufo_born=0,
		spd_multiplier=1,
	}
	if dev then
		gg.score1=0
		gg.score2=0
		gg.ufo_born=5
		gg.spd_multiplier=5
		gg.ships=0
		-- gg.is_title=false
		-- gg.is_gameover=true
		-- gg.key_wait=240
	end
end
gg_reset()
pp_reset=function() -- planet state
	pp={
		base_x=sw/2,
		base_y=sh-100,
		scale=2,
	}
end
pp_reset()

function _init()
	f=0 -- every frame +1
	-- srand(0) -- not work on Picotron
	gg_reset()
	stage=sprite.new()
	stage.__on_shake=false

	_space=space.new()
	_ship=ship.new()
	_enemies=enemies.new()
	_title=title.new()
	stage:add_child(_space)
	stage:add_child(_ship)
	stage:add_child(_enemies)
	stage:add_child(_title)

	-- set up color table
	for i0=0,9 do
		local i=i0
		-- poke4(0x5000+i0*4,(mid(0,i*10,255)<<8)+(mid(0,i*1,255)<<0)) -- 녹색 계열
    -- poke4(0x5000+i0*4,(mid(0,i*7,255)<<16)+(mid(0,i*9,255)<<8)+(mid(0,i*9,255)<<0)) -- 흰색에 가깝게
		poke4(0x5000+i0*4,(mid(0,i*8,255)<<16)+(mid(0,i*8,255)<<8)+(mid(0,i*9,255)<<0)) -- 흰색에 더 가깝게
  end
	poke4(0x5000+9*4,0x688878)
	poke4(0x5000+10*4,0x98d0c0)
	poke4(0x5000+11*4,0xccffee)
	for i0=16,26 do
		local i=i0-16
		poke4(0x5000+i0*4,(mid(0,i*6,255)<<8)+(mid(0,i*9,255)<<0))
	end
	poke4(0x5000+27*4,0x0090c0)
end
function _update()
	f+=1
	-- stage:emit_update()
	if(stage.__on_shake) shaking()

	-- 좌우 키로 지형 스케일xy
	-- if btn(0) then planet.scale_x+=0.05 planet.scale_y+=0.004
	-- elseif btn(1) then planet.scale_x-=0.05 planet.scale_y-=0.004 end

	-- 상하 키로 지형 스케일
	-- if btn(2) then pp.scale+=0.02
	-- elseif btn(3) then pp.scale=max(0.25,pp.scale-0.02) end
	if btn(2) then pp.scale*=1.03
	elseif btn(3) then pp.scale=max(0.01,pp.scale*0.97) end

	-- 상하 키로 지형 고도
	-- if btn(2) then pp.base_y-=2
	-- elseif btn(3) then pp.base_y+=2 end
	-- 좌우 키로 좌우 이동
	if btn(0) then pp.base_x-=2
	elseif btn(1) then pp.base_x+=2 end
	
end

clsp={0x7f7f,0xbfbf,0xdfdf,0xefef,0xf7f7,0xfbfb,0xfdfd,0xfefe} -- 4x2에 점 하나씩 스캔라인 순환
clsp2={0xedb7,0x7edb,0xb7ed,0xdb7e}  -- 대각선 라인 오른쪽으로 순환
cls1={11,10,9,8,7,6,5,4,3,2,1,0} -- 이전 프레임의 색상을 점점 어둡게(커스텀 팔레트)
cls2={27,26,25,24,23,22,21,20,19,18,17,16}
hud_top=4
hud_top_default=4

function _draw()

	t0=t()

	-- cls(0)
	for i=1,#cls1-1 do poke(0x8000+cls1[i],cls1[i+1]) end
  for i=1,#cls2-1 do poke(0x8000+cls2[i],cls2[i+1]) end
	fillp(clsp[flr((t()*30)%#clsp+1)])
	rectfill(0,0,sw,sh,32)
	fillp()

	stage:render(0,0)

	-- draw_lunar()
	draw_planet(pp.base_x,pp.base_y)

	-- ui
	if not (gg.is_title or gg.is_gameover) then

		-- hud_top 좌표가 ship에 밀려 올라감
		-- local ty=hud_top_default
		-- if (not _ship.is_killed and _ship.y<32) ty=_ship.y-28
		-- hud_top=hud_top+(ty-hud_top)*0.3

		print_score(sw/2,hud_top)

		-- remain ships
		for i=0,gg.ships-1 do
			draw_shape(s_ship2,7+i*10+shake_diff(),hud_top+4+shake_diff(),cc)
		end

		-- shield text
		local r=_ship.shield_timer/_ship.shield_timer_max
		local t=round(r*100)
		for i=#t,2 do t=" "..t end
		t="shield "..t.."%"
		local w=_ship.shield_timer/_ship.shield_timer_max*74
		if(not _ship.shield_enable and f%30<15) t="" w=0
		print57(t,sw-4,hud_top,cc,1) -- shield text
	end

	-- shake effect
	if stage.__on_shake then
		fillp(0x000f)
		local d=flr(abs(shake_diff()*1.5))
		for i=1,d do
			local y=rnd(sh)
			line(0,y,sw,y-8,cc)
		end
		fillp()
		for i=0,68 do poke(0x5400+i,d) end -- scanline effect
	else
		for i=0,68 do poke(0x5400+i,0) end -- remove scanline effect
	end

	if dev then
		print57("ufo born:"..gg.ufo_born,3,60,cc,0)
		print57("speed:"..gg.spd_multiplier,3,70,cc,0)
		print57("bullet:".._ship.bullet_remain,3,80,cc,0)
	end

	draw_cross_pattern()
	-- draw_color_table()

	-- log
	if dev and log_txt then
		for i=1,#log_txt do
			print(log_txt[i],4,4+(i-1)*10,14)
		end
	end

	
	print(t()-t0,10,100,14)
	
end

function log(s)
	add(log_txt,s)
end