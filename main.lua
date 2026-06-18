-- ╔══════════════════════════════════╗
-- ║   LUNAR LANDER  for Picotron     ║
-- ║   480×270  |  Lua 5.4           ║
-- ╚══════════════════════════════════╝

-- 버전 정보
VERSION    = "v0.19.0"
BUILD_TIME = "2026-06-18 (build 38)"

-- ─── 상수 ─────────────────────────────────────────────────────
W         = 480
H         = 270
GRAVITY   = 0.012         -- 0.015 * 0.8
THRUST    = 0.035         -- 추력도 약하게
ROT_SPD   = 2.5
FUEL_MAX  = 1200
SAFE_VY   = 1.8
SAFE_VX   = 1.2
SAFE_ANG  = 18
SOFT_SPD  = 0.9          -- 이 속도 이하면 "부드러운 착륙" 보너스
PAD_W     = 50
STARS_N   = 80
TRAIL_MAX = 30
WORLD_W   = 2400

-- 타이틀/인트로
TITLE_SCROLL = 1.2       -- 타이틀에서 지형이 흐르는 속도(=초기 비행 속도)
INTRO_FRAMES = 60        -- 분리까지 걸리는 시간(약 1초 @60fps)
STAR_ZOOM_K  = 0.35      -- 별이 줌에 반응하는 비율(지형보다 약하게)

-- 착륙 채점 세부 항목 (UI 표시용)
scoring = {base=0, mult=1, foot="none", ang_b=0, spd_b=0, ctr_b=0, total=0}

-- 게임 모드 플래그
DEBUG_MODE = false
ZOOM_MIN  = 0.25
ZOOM_MAX  = 1.8

-- 완전 흑백: 검정=0, 흰색=7 딱 2가지만
BG  = 0   -- 배경 / 채우기
FG  = 7   -- 전경 / 선

-- ─── 유틸 ─────────────────────────────────────────────────────
function lerp(a, b, t)       return a + (b-a)*t end
function clamp(v, lo, hi)    return math.max(lo, math.min(hi, v)) end
function deg2rad(d)           return d * math.pi / 180 end

function world_to_screen(wx, wy)
  -- 무한 스크롤: wx와 cam_x의 차이를 항상 최단 거리로 정규화
  -- (경계에서 cam_x와 오브젝트가 서로 다르게 wrap되어도 한 프레임 튀지 않게)
  local dx = wx - cam_x
  if dx >  WORLD_W/2 then dx = dx - WORLD_W end
  if dx < -WORLD_W/2 then dx = dx + WORLD_W end
  return W/2 + dx * cam_zoom,
         H/2 + (wy - cam_y) * cam_zoom
end

-- ─── trifill (scan-line) ──────────────────────────────────────
function trifill(x0,y0, x1,y1, x2,y2, col)
  if y0 > y1 then x0,y0,x1,y1 = x1,y1,x0,y0 end
  if y1 > y2 then x1,y1,x2,y2 = x2,y2,x1,y1 end
  if y0 > y1 then x0,y0,x1,y1 = x1,y1,x0,y0 end
  local function fb(ax,ay, bx,by, cx,cy)
    local h = by-ay; if h==0 then return end
    for y=math.floor(ay),math.floor(by) do
      local t=(y-ay)/h
      local lx=ax+(bx-ax)*t; local rx=ax+(cx-ax)*t
      if lx>rx then lx,rx=rx,lx end
      line(math.floor(lx),y,math.ceil(rx),y,col)
    end
  end
  local function ft(ax,ay, bx,by, cx,cy)
    local h=cy-ay; if h==0 then return end
    for y=math.floor(ay),math.floor(cy) do
      local t=(y-ay)/h
      local lx=ax+(cx-ax)*t; local rx=bx+(cx-bx)*t
      if lx>rx then lx,rx=rx,lx end
      line(math.floor(lx),y,math.ceil(rx),y,col)
    end
  end
  local iy0,iy1,iy2=math.floor(y0),math.floor(y1),math.floor(y2)
  if iy1==iy2 then fb(x0,y0,x1,y1,x2,y2)
  elseif iy0==iy1 then ft(x0,y0,x1,y1,x2,y2)
  else
    local t=(y1-y0)/(y2-y0); local mx=x0+(x2-x0)*t
    fb(x0,y0,x1,y1,mx,y1); ft(x1,y1,mx,y1,x2,y2)
  end
end

-- ─── 지형 생성 ────────────────────────────────────────────────
function gen_terrain(lvl)
  local pts,pd = {},{}
  local step = 12 + math.random(3)
  local start_y = 180
  local MAX_SLOPE = math.tan(math.rad(85))   -- 85도 = 기울기 약 11.43
  local max_dy = MAX_SLOPE * step            -- 인접 점 최대 y 변화량

  -- 큰 흐름(저주파) 베이스라인: 완만한 언덕/계곡
  local amp1 = 40 + math.random(20)
  local amp2 = 16 + math.random(12)
  local ph1  = math.random()*math.pi*2
  local ph2  = math.random()*math.pi*2
  local freq1 = (1.3 + math.random()*0.7)
  local freq2 = (3.0 + math.random()*1.5)
  local function baseline(wx)
    local t = wx / WORLD_W
    return start_y
      + amp1 * math.sin(t*math.pi*2*freq1 + ph1)
      + amp2 * math.sin(t*math.pi*2*freq2 + ph2)
  end

  -- 패드 배율 분배: x1 1~2개, x2 1~2개, x3 1개
  local mults = {}
  local n1 = math.random(1,2)
  local n2 = math.random(1,2)
  for i=1,n1 do mults[#mults+1]=1 end
  for i=1,n2 do mults[#mults+1]=2 end
  mults[#mults+1]=3
  for i=#mults,2,-1 do
    local j=math.random(i); mults[i],mults[j]=mults[j],mults[i]
  end
  local pad_count = #mults

  local pad_pos = {}
  local slots = math.floor(WORLD_W/step) - 4
  local seg = math.floor(slots / pad_count)
  for i=1,pad_count do
    local base = (i-1)*seg + 2
    pad_pos[i] = (base + math.random(0, math.max(1, seg-4))) * step
  end
  local order = {}
  for i=1,pad_count do order[i]=i end
  for a=1,pad_count do for b=a+1,pad_count do
    if pad_pos[order[b]] < pad_pos[order[a]] then
      order[a],order[b]=order[b],order[a]
    end
  end end
  local sorted_pos, sorted_mult = {},{}
  for i,idx in ipairs(order) do
    sorted_pos[i]=pad_pos[idx]; sorted_mult[i]=mults[idx]
  end
  pad_pos, mults = sorted_pos, sorted_mult

  -- raw 점 생성 (각 점에 is_pad 표시; 패드는 평탄 보존)
  local raw = {}
  local pi=1; local nxt=pad_pos[pi]; local x=0
  local y = baseline(0)
  local flat_run = 0   -- 연속 평탄 구간 카운트(패드 아닌 곳)
  while x < WORLD_W do
    if nxt and math.abs(x-nxt)<step/2 then
      local mult = mults[pi]
      local pw = (mult==3) and math.floor(PAD_W*0.6)
              or (mult==2) and math.floor(PAD_W*0.8)
              or PAD_W

      -- 위로 솟는 벽을 만드는 헬퍼: 패드 높이에서 시작해 위로(y 감소) 솟음
      local depth = 4
      local wall_h = (max_dy*0.85) * depth     -- 벽 높이(가파른 경사)
      local function rise_wall(from_y)
        -- 패드 높이(from_y)에서 위로 wall_h 만큼 솟는 경사 (smoothstep)
        local top_y = clamp(from_y - wall_h, 110, from_y-40)
        for k=1,depth do
          local t = k/depth
          local ts = t*t*(3-2*t)
          y = lerp(from_y, top_y, ts)
          table.insert(raw, {x=x, y=y})
          x = x + step
        end
      end
      local function flat_run_pts(from_y, cnt)
        -- 패드 양옆을 평탄하게 (살짝의 베이스라인 따라가기)
        for k=1,cnt do
          y = from_y
          table.insert(raw, {x=x, y=y})
          x = x + step
        end
      end

      if mult==3 then
        -- x3: 아래로 움푹 파인 협곡 바닥. 양옆은 가파르게 위로 솟은 벽.
        -- 진입 직전 지형 높이를 기준으로 그보다 훨씬 아래에 패드를 둔다.
        local ref_y = (#raw>0) and raw[#raw].y or baseline(x)
        local pad_y = clamp(ref_y + 70, 200, 245)   -- 주변보다 확실히 아래(깊은 바닥)
        -- 협곡 벽 꼭대기: 패드보다 충분히 위(주변 지형 수준 이상)
        local top_y = clamp(pad_y - 90, 110, pad_y - 70)
        -- 왼쪽 벽: 꼭대기 → 바닥으로 가파르게 하강 (점을 적게 써서 좁고 가파르게)
        local wd = 3
        if #raw>0 then raw[#raw].y = top_y end
        for k=1,wd do
          local t=k/wd; local ts=t*t*(3-2*t)
          y = lerp(top_y, pad_y, ts)
          table.insert(raw, {x=x, y=y}); x = x + step
        end
        -- 패드(평탄, 협곡 바닥)
        if #raw>0 then raw[#raw].y = pad_y end
        table.insert(pd,  {x=x, y=pad_y, w=pw, mult=mult})
        table.insert(raw, {x=x,    y=pad_y, is_pad=true})
        table.insert(raw, {x=x+pw, y=pad_y, is_pad=true})
        x = x + pw; y = pad_y
        -- 오른쪽 벽: 바닥 → 꼭대기로 가파르게 상승
        for k=1,wd do
          local t=k/wd; local ts=t*t*(3-2*t)
          y = lerp(pad_y, top_y, ts)
          table.insert(raw, {x=x, y=y}); x = x + step
        end
        pi=pi+1; nxt=pad_pos[pi]; flat_run = 0

      elseif mult==2 then
        -- x2: 한쪽에만 위로 솟는 벽, 반대쪽은 평탄
        local pad_y = clamp(baseline(x), 140, 215)
        local wall_left = (math.random() < 0.5)
        if wall_left then
          -- 왼쪽 벽 (위에서 패드로 내려옴)
          local top_y = clamp(pad_y - wall_h, 110, pad_y-40)
          if #raw>0 then raw[#raw].y = top_y end
          for k=1,depth do
            local t=k/depth; local ts=t*t*(3-2*t)
            y = lerp(top_y, pad_y, ts)
            table.insert(raw, {x=x, y=y}); x = x + step
          end
        else
          -- 왼쪽 평탄
          if #raw>0 then raw[#raw].y = pad_y end
          flat_run_pts(pad_y, 2)
        end
        -- 패드
        if #raw>0 then raw[#raw].y = pad_y end
        table.insert(pd,  {x=x, y=pad_y, w=pw, mult=mult})
        table.insert(raw, {x=x,    y=pad_y, is_pad=true})
        table.insert(raw, {x=x+pw, y=pad_y, is_pad=true})
        x = x + pw; y = pad_y
        -- 반대쪽
        if wall_left then
          flat_run_pts(pad_y, 2)        -- 오른쪽 평탄
        else
          rise_wall(pad_y)              -- 오른쪽 벽
        end
        pi=pi+1; nxt=pad_pos[pi]; flat_run = 0

      else
        -- x1: 좌우 모두 평탄
        local pad_y = clamp(baseline(x), 130, 225)
        if #raw>0 then raw[#raw].y = pad_y end
        flat_run_pts(pad_y, 2)          -- 왼쪽 평탄
        table.insert(pd,  {x=x, y=pad_y, w=pw, mult=mult})
        table.insert(raw, {x=x,    y=pad_y, is_pad=true})
        table.insert(raw, {x=x+pw, y=pad_y, is_pad=true})
        x = x + pw; y = pad_y
        flat_run_pts(pad_y, 2)          -- 오른쪽 평탄
        pi=pi+1; nxt=pad_pos[pi]; flat_run = 0
      end
    else
      -- 베이스라인 + 노이즈
      local noise = (math.random()-0.5) * 14 * (1+lvl*0.06)
      local ny = clamp(baseline(x) + noise, 110, 245)
      -- 너무 평탄하면(직전과 y차 작음) 기복 강제 (패드 아닌 곳)
      if #raw>0 and math.abs(ny - raw[#raw].y) < 3 then
        flat_run = flat_run + 1
        ny = clamp(ny + (math.random()<0.5 and -1 or 1)*math.random(5,11), 110, 245)
      else
        flat_run = 0
      end
      table.insert(raw,{x=x,y=ny})
      x=x+step
    end
  end

  -- 끝부분을 시작 높이로 부드럽게 블렌드 (이음새 연결)
  local y0 = baseline(0)
  local blend_start = WORLD_W * 0.88
  for i=1,#raw do
    local p = raw[i]
    if p.x >= blend_start and not p.is_pad then
      local t = clamp((p.x-blend_start)/(WORLD_W-blend_start), 0, 1)
      local ts = t*t*(3-2*t)
      p.y = lerp(p.y, y0, ts)
    end
  end

  -- 후처리: 인접 점 기울기를 85도로 제한 (패드는 평탄 보존)
  -- 앞→뒤, 뒤→앞 양방향으로 두 번 훑어 매끄럽게
  for pass=1,2 do
    for i=2,#raw do
      local a, b = raw[i-1], raw[i]
      if not (a.is_pad and b.is_pad) then   -- 패드 내부 평탄은 건드리지 않음
        local dx = b.x - a.x
        if dx > 0 then
          local dy = b.y - a.y
          local lim = MAX_SLOPE * dx
          if dy > lim then b.y = a.y + lim
          elseif dy < -lim then b.y = a.y - lim end
        end
      end
    end
  end

  -- 넓은 수평 제거: 패드가 아닌데 연속으로 평탄하면 완만한 물결 추가
  local run_start = nil
  local function add_wave(s, e)
    -- s..e 구간(인덱스)에 사인 물결 한 굽이
    local span = raw[e].x - raw[s].x
    if span <= 0 then return end
    local amp = 8 + math.random(8)
    local sign = (math.random()<0.5) and 1 or -1
    for k=s,e do
      local t = (raw[k].x - raw[s].x) / span
      raw[k].y = clamp(raw[k].y + sign*amp*math.sin(t*math.pi), 110, 245)
    end
  end
  local i = 2
  while i <= #raw do
    if not raw[i].is_pad and not raw[i-1].is_pad
       and math.abs(raw[i].y - raw[i-1].y) < 1.5 then
      if not run_start then run_start = i-1 end
    else
      if run_start and (i-1 - run_start) >= 2 then
        add_wave(run_start, i-1)
      end
      run_start = nil
    end
    i = i + 1
  end

  -- 물결 추가로 생긴 급경사 재클램프
  for i=2,#raw do
    local a, b = raw[i-1], raw[i]
    if not (a.is_pad and b.is_pad) then
      local dx = b.x - a.x
      if dx > 0 then
        local dy = b.y - a.y
        local lim = MAX_SLOPE * dx
        if dy > lim then b.y = a.y + lim
        elseif dy < -lim then b.y = a.y - lim end
      end
    end
  end

  -- 무한 스크롤 이음새 해결:
  -- 한 벌의 끝(x=WORLD_W, y0)과 다음 벌 시작(x=0, 첫 점)이 만나므로
  -- 시작 부분도 y0로 블렌드하고, 첫 점을 정확히 y0로 고정.
  local blend_head = WORLD_W * 0.06
  for i=1,#raw do
    local p = raw[i]
    if p.x <= blend_head and not p.is_pad then
      local t = clamp(p.x / blend_head, 0, 1)
      local ts = t*t*(3-2*t)
      p.y = lerp(y0, p.y, ts)
    end
  end
  if #raw > 0 and not raw[1].is_pad then raw[1].y = y0 end

  -- 같은 x에 점이 둘 있으면(수직 단차 원인) 패드 점을 우선해 정리
  local cleaned = {}
  for i=1,#raw do
    local p = raw[i]
    local prev = cleaned[#cleaned]
    if prev and math.abs(prev.x - p.x) < 0.5 then
      -- x 중복: 패드 점을 살리고 아니면 평균으로 합침
      if p.is_pad and not prev.is_pad then
        cleaned[#cleaned] = p           -- 패드 점으로 교체
      elseif prev.is_pad and not p.is_pad then
        -- 기존(패드) 유지, 새 점 버림
      else
        prev.y = (prev.y + p.y) * 0.5   -- 둘 다 같은 종류면 평균
      end
    else
      cleaned[#cleaned+1] = p
    end
  end
  raw = cleaned

  for i=1,#raw do table.insert(pts, raw[i]) end
  table.insert(pts, {x=WORLD_W, y=y0})
  table.insert(pts, {x=WORLD_W, y=300})
  table.insert(pts, {x=0,       y=300})
  terrain_surf_n = #pts - 2   -- 표면 점 개수 (이진 탐색용)
  return pts,pd
end

function terrain_y_at(wx)
  -- 무한 스크롤: wx를 [0, WORLD_W] 범위로 wrap
  wx = wx % WORLD_W
  -- 표면 점만 이진 탐색 (마지막 3개는 닫기용이라 제외)
  local npts = terrain_surf_n or (#terrain_pts - 2)
  local lo, hi = 1, npts - 1
  -- 경계 처리
  if wx <= terrain_pts[1].x then return terrain_pts[1].y end
  if wx >= terrain_pts[npts].x then return terrain_pts[npts].y end
  while lo <= hi do
    local mid = (lo + hi) // 2
    local p0 = terrain_pts[mid]
    local p1 = terrain_pts[mid+1]
    if wx < p0.x then
      hi = mid - 1
    elseif wx > p1.x then
      lo = mid + 1
    else
      local dx = p1.x - p0.x
      if dx <= 0 then return p0.y end
      return lerp(p0.y, p1.y, (wx - p0.x) / dx)
    end
  end
  return 300
end

-- ─── 별 ───────────────────────────────────────────────────────
STAR_PARALLAX = 0.15
STAR_WORLD_W  = WORLD_W * 3

function gen_stars()
  local s={}
  for i=1,STARS_N do
    s[i]={
      wx    = math.random(0, STAR_WORLD_W),
      y     = math.random(2, H-30),   -- 화면 거의 전체 높이
      cross = (math.random() < 0.2),
    }
  end
  return s
end

-- ─── 착륙선 ───────────────────────────────────────────────────
function new_lander()
  local sx=WORLD_W/2
  local gy=terrain_y_at(sx)
  return {x=sx, y=gy-450, vx=(math.random()-0.5)*0.7,
          vy=0.1, ang=0, fuel=FUEL_MAX, alive=true,
          settling=false, settle_t=0, landed_on_pad=false, pad_mult=1}
end

-- ─── 파티클 ───────────────────────────────────────────────────
function spawn_particle(px,py,vx,vy,life,col,sz)
  table.insert(particles_list,{x=px,y=py,vx=vx,vy=vy,
    life=life,max_life=life,col=col,sz=sz or 1})
end
-- 먼지 전용 (지형보다 뒤에 그림, 원→점으로 줄어듦)
-- grav: 중력 계수 (기본 0.01, 폭발 파편은 더 크게)
function spawn_dust(px,py,vx,vy,life,r0,grav,front)
  table.insert(dust_list,{x=px,y=py,vx=vx,vy=vy,
    life=life,max_life=life,r0=r0,grav=grav or 0.01,front=front or false})
end

-- 폭발: 착륙선 몸통을 완전히 뒤덮은 채로 시작 → 사방으로 흩어짐
-- 먼지와 같은 형식(속 검정 + 흰 테두리 원, 점으로 축소), 달 중력 적용
function explode(l)
  local cs = math.cos(deg2rad(l.ang))
  local sn = math.sin(deg2rad(l.ang))
  -- 몸통 box 영역(BODY_BOX_L..R, T..B)을 격자로 촘촘히 채워 시작
  local step = 1.6
  for bx = BODY_BOX_L, BODY_BOX_R, step do
    for by = BODY_BOX_T, BODY_BOX_B, step do
      -- 로컬 → 세계 (회전 적용)
      local wx = l.x + cs*bx - sn*by
      local wy = l.y + sn*bx + cs*by
      -- 중심에서 바깥으로 터지는 속도
      local dx = wx - l.x
      local dy = wy - l.y
      local d  = math.sqrt(dx*dx+dy*dy) + 0.001
      local spd = math.random()*1.8 + 0.6
      local vx = (dx/d)*spd + (math.random()-0.5)*0.8
      local vy = (dy/d)*spd + (math.random()-0.5)*0.8 - 0.6
      local r0 = math.random(2,4)
      spawn_dust(wx, wy, vx, vy, math.random(28,46), r0, 0.04, true)
    end
  end
  -- 추가로 작은 불똥 몇 개
  for i=1,16 do
    local a=math.random()*math.pi*2
    local s=math.random()*3+1
    spawn_dust(l.x, l.y, math.cos(a)*s, math.sin(a)*s-0.8,
      math.random(20,36), math.random(1,2), 0.04, true)
  end
  -- 화면 진동
  shake_t = 26
end
function landing_puff(x,y)
  for i=1,12 do
    local a=math.pi+(math.random()-0.5)*math.pi*0.8
    local s=math.random()*1.2+0.3
    spawn_dust(x,y,math.cos(a)*s,math.sin(a)*s,
      math.random(15,30),math.random(1,2),0.01)
  end
end

-- 노즐 위치와 분사 방향, 지형 충돌점 계산 (먼지/디버그 공용)
DUST_MAX_DIST = 90   -- 먼지 발생 최대 거리 (기존 130의 ~70%)
function nozzle_ray(l)
  local r  = deg2rad(l.ang)
  local cs, sn = math.cos(r), math.sin(r)
  -- 노즐 위치: draw_lander의 rp(0,12)와 동일
  local nx = l.x + (-sn * 12)
  local ny = l.y + ( cs * 12)
  local dx, dy = -sn, cs   -- 분사 방향 (단위벡터)
  -- 지형 충돌점 찾기
  for d = 0, DUST_MAX_DIST, 3 do
    local px = nx + dx * d
    local py = ny + dy * d
    if py >= terrain_y_at(px) then
      return nx, ny, dx, dy, px, terrain_y_at(px), d
    end
  end
  return nx, ny, dx, dy, nil, nil, nil
end

-- 추력 시 지면 먼지
function thrust_dust(l)
  local nx, ny, dir_x, dir_y, hit_x, hit_y, dist = nozzle_ray(l)
  if not hit_x then return end

  local intensity = 1 - (dist / DUST_MAX_DIST)
  local count = 1 + math.floor(intensity * 4)

  -- 지형 표면 접선 방향 (정규화)
  local g_left  = terrain_y_at(hit_x - 6)
  local g_right = terrain_y_at(hit_x + 6)
  local tang_x = 12
  local tang_y = g_right - g_left
  local tlen = math.sqrt(tang_x*tang_x + tang_y*tang_y)
  tang_x = tang_x / tlen
  tang_y = tang_y / tlen

  -- 추력 분사 방향을 지형 접선에 투영 → 먼지 우세 방향
  local flow = dir_x * tang_x + dir_y * tang_y

  for i=1,count do
    local side
    if math.random() < (0.5 + flow*0.4) then side = 1 else side = -1 end
    local spd = (math.random()*1.2 + 0.4) * (0.5 + intensity)
    if side * (flow>0 and 1 or -1) > 0 then
      spd = spd * (1 + math.abs(flow)*0.8)
    end
    local vx = tang_x * side * spd
    local vy = tang_y * side * spd - math.random()*0.25
    local r0 = 1 + math.floor(intensity * 3 + math.random()*1.5)
    spawn_dust(hit_x, hit_y - 1, vx, vy, math.random(16,30), r0)
  end
end

function add_trail(x,y)
  table.insert(trail_list,{x=x,y=y,life=TRAIL_MAX})
  if #trail_list>TRAIL_MAX then table.remove(trail_list,1) end
end

-- ─── 카메라 ───────────────────────────────────────────────────
function update_camera()
  local l=lander
  -- 착륙선 주변 여러 지점의 지형을 샘플링해 평균 → 국소 협곡에 덜 민감
  local sum, cnt, lowest = 0, 0, -1e9
  for off = -60, 60, 20 do
    local gy = terrain_y_at(l.x + off)
    sum = sum + gy; cnt = cnt + 1
    if gy > lowest then lowest = gy end   -- 가장 낮은 지형(y 큼)
  end
  local avg_ground = sum / cnt
  -- 평균과 최저 지형을 섞어 기준 바닥 결정 (협곡 급변 완화)
  local ground = lerp(avg_ground, lowest, 0.4)

  local world_top    = l.y - 60
  local world_bottom = ground + 30
  local world_span   = world_bottom - world_top
  if world_span<1 then world_span=1 end
  local target_zoom = clamp((H-32)/world_span, ZOOM_MIN, ZOOM_MAX)
  -- 줌은 더 느리게 보간 (고도 변화에 덜 민감)
  cam_zoom = lerp(cam_zoom, target_zoom, 0.03)

  -- cam_x wrap: 착륙선과의 차이를 [-WORLD_W/2, WORLD_W/2] 로 제한
  local dx = l.x - cam_x
  if dx >  WORLD_W/2 then dx = dx - WORLD_W end
  if dx < -WORLD_W/2 then dx = dx + WORLD_W end
  local move = dx * 0.1
  cam_x = cam_x + move
  cam_x = cam_x % WORLD_W
  -- 별 시차용 누적 스크롤(wrap 안 함 → 경계에서 점프 없음)
  star_scroll = (star_scroll or 0) + move

  cam_y = lerp(cam_y, (world_top+world_bottom)/2, 0.05)
end

-- ─── 착륙선 LOD (히스테리시스 3단계) ────────────────────────
-- z = cam_zoom*0.5 기준. 단계가 톡톡 바뀌지 않도록 올라갈 때와
-- 내려갈 때 임계값을 다르게 둔다(히스테리시스).
--   LOD0=풀디테일, LOD1=중간, LOD2=단순 실루엣
lander_lod = 0
function update_lod(z)
  local cur = lander_lod
  -- 내려가는(멀어지는) 경계와 올라가는(가까워지는) 경계를 분리
  if cur == 0 then
    if z < 0.62 then cur = 1 end
  elseif cur == 1 then
    if z < 0.42 then cur = 2
    elseif z > 0.78 then cur = 0 end
  else -- cur == 2
    if z > 0.50 then cur = 1 end
  end
  lander_lod = cur
  return cur
end

-- 발판 로컬: rp(±23, 20) → 물리 오프셋: (±11.5, 10)
LANDER_FOOT_X = 12
LANDER_FOOT_Y = 10

-- 몸통 충돌 box (발 제외). 뾰족한 지형 관통 감지용으로 아래쪽 넉넉히
BODY_BOX_L = -5
BODY_BOX_R =  5
BODY_BOX_T = -5
BODY_BOX_B =  8   -- 아래쪽 확장 (발끝 LANDER_FOOT_Y=10 직전까지)

function draw_lander(l)
  local r=deg2rad(l.ang)
  local cs,sn=math.cos(r),math.sin(r)
  local z=cam_zoom*0.5
  local lsx,lsy=world_to_screen(l.x,l.y)
  local function rp(px,py)
    return math.floor(lsx+(cs*px-sn*py)*z),
           math.floor(lsy+(sn*px+cs*py)*z)
  end

  local lod = update_lod(z)

  -- ── LOD2: 단순 실루엣 (가장 멀리) ─────────────────────────
  if lod == 2 then
    -- 몸통
    local b1x,b1y=rp(-8,-8); local b2x,b2y=rp(8,-8)
    local b3x,b3y=rp(10,8);  local b4x,b4y=rp(-10,8)
    trifill(b1x,b1y,b2x,b2y,b3x,b3y,BG)
    trifill(b1x,b1y,b3x,b3y,b4x,b4y,BG)
    line(b1x,b1y,b2x,b2y,FG); line(b2x,b2y,b3x,b3y,FG)
    line(b3x,b3y,b4x,b4y,FG); line(b4x,b4y,b1x,b1y,FG)
    -- 돔
    do
      local d1x,d1y=rp(-5,-8); local d2x,d2y=rp(5,-8); local d3x,d3y=rp(0,-14)
      trifill(d1x,d1y,d2x,d2y,d3x,d3y,BG)
      line(d1x,d1y,d2x,d2y,FG); line(d2x,d2y,d3x,d3y,FG); line(d3x,d3y,d1x,d1y,FG)
    end
    -- 왼쪽 다리
    do
      local ax,ay=rp(-10,8); local bx,by=rp(-20,18)
      local cx,cy=rp(-24,18); local dx,dy=rp(-15,18)
      line(ax,ay,bx,by,FG); line(cx,cy,dx,dy,FG)
    end
    -- 오른쪽 다리
    do
      local ax,ay=rp(10,8); local bx,by=rp(20,18)
      local cx,cy=rp(15,18); local dx,dy=rp(24,18)
      line(ax,ay,bx,by,FG); line(cx,cy,dx,dy,FG)
    end
    return
  end

  -- ── LOD0: 풀 디테일 ───────────────────────────────────────

  -- 다리 (동체보다 먼저)
  do
    local ax,ay=rp(-12,8); local bx,by=rp(-24,20)
    local cx,cy=rp(-28,20); local dx,dy=rp(-18,20)
    line(ax,ay,bx,by,FG); line(cx,cy,dx,dy,FG)
    local sx,sy=rp(-6,2); local ex,ey=rp(-18,14)
    line(sx,sy,ex,ey,FG)
  end
  do
    local ax,ay=rp(12,8); local bx,by=rp(24,20)
    local cx,cy=rp(18,20); local dx,dy=rp(28,20)
    line(ax,ay,bx,by,FG); line(cx,cy,dx,dy,FG)
    local sx,sy=rp(6,2); local ex,ey=rp(18,14)
    line(sx,sy,ex,ey,FG)
  end
  -- 하강단
  local h1x,h1y=rp(-10,-2); local h2x,h2y=rp(10,-2)
  local h3x,h3y=rp(14,8);   local h4x,h4y=rp(-14,8)
  trifill(h1x,h1y,h2x,h2y,h3x,h3y,BG); trifill(h1x,h1y,h3x,h3y,h4x,h4y,BG)
  line(h1x,h1y,h2x,h2y,FG); line(h2x,h2y,h3x,h3y,FG)
  line(h3x,h3y,h4x,h4y,FG); line(h4x,h4y,h1x,h1y,FG)
  if lod == 0 then
    -- 하강단 격자 디테일 (가까울 때만)
    local g1x,g1y=rp(-4,-2); local g2x,g2y=rp(-5,8)
    local g3x,g3y=rp(4,-2);  local g4x,g4y=rp(5,8)
    line(g1x,g1y,g2x,g2y,FG); line(g3x,g3y,g4x,g4y,FG)
    local m1x,m1y=rp(-11,3); local m2x,m2y=rp(11,3)
    line(m1x,m1y,m2x,m2y,FG)
  end
  -- 노즐
  do
    local n1x,n1y=rp(-4,8);  local n2x,n2y=rp(4,8)
    local n3x,n3y=rp(3,14);  local n4x,n4y=rp(-3,14)
    trifill(n1x,n1y,n2x,n2y,n3x,n3y,BG); trifill(n1x,n1y,n3x,n3y,n4x,n4y,BG)
    line(n1x,n1y,n2x,n2y,FG); line(n2x,n2y,n3x,n3y,FG)
    line(n3x,n3y,n4x,n4y,FG); line(n4x,n4y,n1x,n1y,FG)
  end
  -- 상승단
  local u1x,u1y=rp(-8,-2);  local u2x,u2y=rp(8,-2)
  local u3x,u3y=rp(8,-10);  local u4x,u4y=rp(-8,-10)
  trifill(u1x,u1y,u2x,u2y,u3x,u3y,BG); trifill(u1x,u1y,u3x,u3y,u4x,u4y,BG)
  line(u1x,u1y,u2x,u2y,FG); line(u2x,u2y,u3x,u3y,FG)
  line(u3x,u3y,u4x,u4y,FG); line(u4x,u4y,u1x,u1y,FG)
  do local m1x,m1y=rp(0,-2); local m2x,m2y=rp(0,-10); line(m1x,m1y,m2x,m2y,FG) end
  if lod == 0 then
    -- 상승단 측면 포드 (가까울 때만)
    local p1x,p1y=rp(-8,-4);  local p2x,p2y=rp(-12,-4)
    local p3x,p3y=rp(-12,-8); local p4x,p4y=rp(-8,-8)
    trifill(p1x,p1y,p2x,p2y,p3x,p3y,BG); trifill(p1x,p1y,p3x,p3y,p4x,p4y,BG)
    line(p1x,p1y,p2x,p2y,FG); line(p2x,p2y,p3x,p3y,FG)
    line(p3x,p3y,p4x,p4y,FG); line(p4x,p4y,p1x,p1y,FG)
    local q1x,q1y=rp(8,-4);   local q2x,q2y=rp(12,-4)
    local q3x,q3y=rp(12,-8);  local q4x,q4y=rp(8,-8)
    trifill(q1x,q1y,q2x,q2y,q3x,q3y,BG); trifill(q1x,q1y,q3x,q3y,q4x,q4y,BG)
    line(q1x,q1y,q2x,q2y,FG); line(q2x,q2y,q3x,q3y,FG)
    line(q3x,q3y,q4x,q4y,FG); line(q4x,q4y,q1x,q1y,FG)
  end
  -- 돔
  local c1x,c1y=rp(-6,-10); local c2x,c2y=rp(6,-10)
  local c3x,c3y=rp(8,-14);  local c4x,c4y=rp(5,-18)
  local c5x,c5y=rp(-5,-18); local c6x,c6y=rp(-8,-14)
  local cc,ccy=rp(0,-14)
  trifill(c1x,c1y,c2x,c2y,cc,ccy,BG); trifill(c2x,c2y,c3x,c3y,cc,ccy,BG)
  trifill(c3x,c3y,c4x,c4y,cc,ccy,BG); trifill(c4x,c4y,c5x,c5y,cc,ccy,BG)
  trifill(c5x,c5y,c6x,c6y,cc,ccy,BG); trifill(c6x,c6y,c1x,c1y,cc,ccy,BG)
  line(c1x,c1y,c2x,c2y,FG); line(c2x,c2y,c3x,c3y,FG)
  line(c3x,c3y,c4x,c4y,FG); line(c4x,c4y,c5x,c5y,FG)
  line(c5x,c5y,c6x,c6y,FG); line(c6x,c6y,c1x,c1y,FG)
  if lod == 0 then
    -- 돔 창문 + 안테나 (가까울 때만)
    local w1x,w1y=rp(-3,-12); local w2x,w2y=rp(3,-12)
    local w3x,w3y=rp(3,-17);  local w4x,w4y=rp(-3,-17)
    trifill(w1x,w1y,w2x,w2y,w3x,w3y,FG); trifill(w1x,w1y,w3x,w3y,w4x,w4y,FG)
    local wcx,wcy1=rp(0,-12); local _,wcy2=rp(0,-17); local _,wmid=rp(0,-14)
    local wxl,_2=rp(-3,-14);  local wxr,_3=rp(3,-14)
    line(wcx,wcy1,wcx,wcy2,BG); line(wxl,wmid,wxr,wmid,BG)
    local a1x,a1y=rp(2,-18); local a2x,a2y=rp(4,-23)
    line(a1x,a1y,a2x,a2y,FG); pset(a2x,a2y,FG)
  end
end

-- ─── 사령선 CSM (아폴로 스타일) ──────────────────────────────
-- 원뿔형 사령선(CM) + 원통형 기계선(SM) + 메인 엔진 노즐.
-- 진행 방향(오른쪽)으로 사령선 원뿔이 앞을 향함.
function draw_csm(c)
  local sx, sy = world_to_screen(c.x, c.y)
  local z = cam_zoom * 0.5 * 1.4   -- 사령선 1.4배 크게
  local function p(px, py)
    return math.floor(sx + px*z), math.floor(sy + py*z)
  end
  -- 좌표계: +x = 진행방향(오른쪽=앞), 사령선 원뿔이 오른쪽 끝
  -- 사령선(CM): 오른쪽 끝 원뿔
  local a1x,a1y = p(22, 0)     -- 원뿔 꼭짓점(앞)
  local a2x,a2y = p(10, -7)    -- 원뿔 밑면 위
  local a3x,a3y = p(10,  7)    -- 원뿔 밑면 아래
  line(a1x,a1y, a2x,a2y, FG)
  line(a1x,a1y, a3x,a3y, FG)
  line(a2x,a2y, a3x,a3y, FG)

  -- 기계선(SM): 원통 (사각형 몸체)
  local b1x,b1y = p(10, -7)
  local b2x,b2y = p(-14, -7)
  local b3x,b3y = p(-14, 7)
  local b4x,b4y = p(10, 7)
  line(b1x,b1y, b2x,b2y, FG)   -- 위
  line(b3x,b3y, b4x,b4y, FG)   -- 아래
  line(b2x,b2y, b3x,b3y, FG)   -- 뒤

  -- 기계선 표면 디테일(세로줄 2개)
  do local s1x,s1y=p(0,-7); local s2x,s2y=p(0,7); line(s1x,s1y,s2x,s2y,FG) end
  do local s1x,s1y=p(-7,-7); local s2x,s2y=p(-7,7); line(s1x,s1y,s2x,s2y,FG) end

  -- 메인 엔진 노즐 (뒤쪽, 종 모양)
  local n1x,n1y = p(-14, -4)
  local n2x,n2y = p(-22, -7)
  local n3x,n3y = p(-22, 7)
  local n4x,n4y = p(-14, 4)
  line(n1x,n1y, n2x,n2y, FG)
  line(n2x,n2y, n3x,n3y, FG)
  line(n3x,n3y, n4x,n4y, FG)

  -- 도킹 중이면 분사 화염(앞으로 비행 → 엔진은 뒤로 분사)
  if c.attached then
    local f1x,f1y = p(-22, -3)
    local f2x,f2y = p(-22, 3)
    local f3x,f3y = p(-22 - math.random(3,8), 0)
    line(f1x,f1y, f3x,f3y, FG)
    line(f2x,f2y, f3x,f3y, FG)
  end
end

-- ─── 화염 ─────────────────────────────────────────────────────
function draw_flame(l)
  local r=deg2rad(l.ang); local cs,sn=math.cos(r),math.sin(r)
  local z=cam_zoom*0.5; local lsx,lsy=world_to_screen(l.x,l.y)
  local function rp(px,py)
    return math.floor(lsx+(cs*px-sn*py)*z),
           math.floor(lsy+(sn*px+cs*py)*z)
  end
  local fl=math.random(6,16)
  -- 모든 줌에서 최소한의 화염 표시
  if z < 0.3 then
    -- 극소: 노즐 방향으로 점 2개
    local nx,ny=rp(0,12); local nx2,ny2=rp(0,12+math.floor(fl*0.4))
    pset(nx,ny,FG); pset(nx2,ny2,FG)
    return
  end
  if z < 0.55 then
    -- 소형: 작은 삼각형
    local ax,ay=rp(-2,10); local bx,by=rp(2,10); local cx,cy=rp(0,10+math.floor(fl*0.6))
    trifill(ax,ay,bx,by,cx,cy,FG); return
  end
  -- 풀 화염 (3레이어)
  do local ax,ay=rp(-6,14); local bx,by=rp(6,14); local cx,cy=rp(0,14+fl)
    trifill(ax,ay,bx,by,cx,cy,FG) end
  do local ax,ay=rp(-4,14); local bx,by=rp(4,14); local cx,cy=rp(0,14+math.floor(fl*0.6))
    trifill(ax,ay,bx,by,cx,cy,BG) end
  do local ax,ay=rp(-2,14); local bx,by=rp(2,14); local cx,cy=rp(0,14+math.floor(fl*0.35))
    trifill(ax,ay,bx,by,cx,cy,FG) end
end

-- ─── 디버그 오버레이 (항상 맨 마지막에 그림) ─────────────────
function draw_debug(l)
  local r2=deg2rad(l.ang); local cs2=math.cos(r2); local sn2=math.sin(r2)
  local function bw2s(px,py)
    local wx = l.x + cs2*px - sn2*py
    local wy = l.y + sn2*px + cs2*py
    return world_to_screen(wx, wy)
  end

  -- 발끝 연결선 (녹색 11)
  local lsx2,lsy2 = bw2s(-LANDER_FOOT_X, LANDER_FOOT_Y)
  local rsx2,rsy2 = bw2s( LANDER_FOOT_X, LANDER_FOOT_Y)
  line(lsx2,lsy2, rsx2,rsy2, 11)
  line(lsx2-3,lsy2, lsx2+3,lsy2, 11); line(lsx2,lsy2-3, lsx2,lsy2+3, 11)
  line(rsx2-3,rsy2, rsx2+3,rsy2, 11); line(rsx2,rsy2-3, rsx2,rsy2+3, 11)

  -- 몸통 충돌 box (색상 14, 청록)
  local c1x,c1y = bw2s(BODY_BOX_L, BODY_BOX_T)
  local c2x,c2y = bw2s(BODY_BOX_R, BODY_BOX_T)
  local c3x,c3y = bw2s(BODY_BOX_R, BODY_BOX_B)
  local c4x,c4y = bw2s(BODY_BOX_L, BODY_BOX_B)
  line(c1x,c1y, c2x,c2y, 14)
  line(c2x,c2y, c3x,c3y, 14)
  line(c3x,c3y, c4x,c4y, 14)
  line(c4x,c4y, c1x,c1y, 14)

  -- 고도선
  local gnd_y = terrain_y_at(l.x)
  local alt   = gnd_y - l.y
  if alt > 15 then
    local sx_c   = math.floor(W/2 + (l.x  - cam_x)*cam_zoom)
    local sy_top = math.floor(H/2 + (l.y  - cam_y)*cam_zoom)
    local sy_bot = math.floor(H/2 + (gnd_y- cam_y)*cam_zoom)
    line(sx_c, sy_top, sx_c, sy_bot, 11)
    print(math.floor(alt), sx_c+3, math.floor((sy_top+sy_bot)/2)-3, 11)
  end

  -- 추력 분사선 (항상 표시) + 먼지 발생점 — 분홍 24, 점선
  local nx,ny,dx,dy,hx,hy,dd = nozzle_ray(l)
  local ex, ey                -- 선 끝점 (지형 충돌점 또는 최대거리)
  if hx then ex,ey = hx,hy
  else ex,ey = nx+dx*DUST_MAX_DIST, ny+dy*DUST_MAX_DIST end
  local nsx,nsy = world_to_screen(nx, ny)
  local esx,esy = world_to_screen(ex, ey)
  -- 점선: 일정 간격으로 점만 찍기
  local steps = 40
  for i=0,steps do
    if i%2==0 then
      local t = i/steps
      local px = nsx + (esx-nsx)*t
      local py = nsy + (esy-nsy)*t
      pset(px, py, 24)
    end
  end
  -- 충돌점 + 표시
  if hx then
    line(esx-3,esy, esx+3,esy, 24)
    line(esx,esy-3, esx,esy+3, 24)
  end
end

-- ─── 벡터 로고 (외곽선 + 입체) ────────────────────────────────
-- 각 글자를 닫힌 경로(폴리곤) 목록으로 정의. 좌표 0~5(x) × 0~7(y).
-- 경로가 여러 개면 바깥+안쪽(구멍) 윤곽. 획에 폭이 있어 두꺼워 보임.
function glyph_paths(ch)
  if ch=="L" then
    return {{ {0,0},{1.6,0},{1.6,5.4},{4,5.4},{4,7},{0,7} }}
  elseif ch=="U" then
    return {
      { {0,0},{1.6,0},{1.6,5.2},{3.4,5.2},{3.4,0},{5,0},{5,5.6},{4,7},{1,7},{0,5.6} },
    }
  elseif ch=="N" then
    return {{ {0,7},{0,0},{1.4,0},{3.6,4.4},{3.6,0},{5,0},{5,7},{3.6,7},{1.4,2.6},{1.4,7} }}
  elseif ch=="A" then
    return {
      { {0,7},{1.7,0},{3.3,0},{5,7},{3.4,7},{3.05,5.4},{1.95,5.4},{1.6,7} },  -- 바깥
      { {2.2,4},{2.8,4},{2.5,2.2} },                                          -- 구멍(삼각)
    }
  elseif ch=="R" then
    return {
      { {0,0},{3.4,0},{4.6,1},{4.6,3},{3.6,4},{5,7},{3.3,7},{2.1,4.3},
        {1.6,4.3},{1.6,7},{0,7} },     -- 바깥
      { {1.6,1.5},{3,1.5},{3,2.8},{1.6,2.8} },   -- 구멍
    }
  elseif ch=="D" then
    return {
      { {0,0},{3,0},{5,2},{5,5},{3,7},{0,7} },        -- 바깥
      { {1.6,1.5},{2.6,1.5},{3.4,2.4},{3.4,4.6},{2.6,5.5},{1.6,5.5} }, -- 구멍
    }
  elseif ch=="E" then
    return {
      { {0,0},{4.6,0},{4.6,1.5},{1.6,1.5},{1.6,2.7},{4,2.7},{4,4.3},
        {1.6,4.3},{1.6,5.5},{4.6,5.5},{4.6,7},{0,7} },
    }
  end
  return {}
end

-- 닫힌 경로를 선으로 그림 (점들을 순환 연결)
function draw_path(path, gx, gy, s, col)
  local n=#path
  for i=1,n do
    local a=path[i]; local b=path[(i%n)+1]
    line(gx+a[1]*s, gy+a[2]*s, gx+b[1]*s, gy+b[2]*s, col)
  end
end

-- 글자 1개: 안/바깥 윤곽 + 우하단 입체 + 측면 연결선
function draw_glyph_3d(ch, gx, gy, s, depth)
  local paths = glyph_paths(ch)
  if #paths==0 then return end
  local outer = paths[1]   -- 첫 경로 = 바깥 윤곽

  -- ① 우하단으로 옮긴 바깥 윤곽 (뒷면)
  draw_path(outer, gx+depth, gy+depth, s, FG)

  -- ② 바깥 윤곽의 각 점과 우하단 점을 잇는 측면선
  for i=1,#outer do
    local p=outer[i]
    local ax,ay = gx+p[1]*s,        gy+p[2]*s
    local bx,by = gx+p[1]*s+depth,  gy+p[2]*s+depth
    line(ax,ay,bx,by,FG)
  end

  -- ③ 앞면: 모든 경로(바깥 + 구멍) 윤곽
  for _,path in ipairs(paths) do
    draw_path(path, gx, gy, s, FG)
  end
end

-- 로고 한 줄
function draw_logo(str, cx, cy, s)
  local GW = 5*s + 1.4*s   -- 글자폭 + 자간
  local SP = 2.8*s
  local total = 0
  for i=1,#str do
    total = total + ((str:sub(i,i)==" ") and SP or GW)
  end
  local x = cx - total/2
  local depth = math.max(2, math.floor(s*0.45))
  for i=1,#str do
    local ch = str:sub(i,i)
    if ch==" " then
      x = x + SP
    else
      draw_glyph_3d(ch, x, cy, s, depth)
      x = x + GW
    end
  end
end

-- ─── 지형 그리기 ─────────────────────────────────────────────
-- 화면의 각 x열마다 월드 좌표로 역변환 → terrain_y_at으로 표면 y를 구해
-- 연속된 폴리라인 + 세로막대 채움. 무한 스크롤 경계든 어디든 끊김 없음.
function draw_terrain()
  if not terrain_pts then return end
  local bot = H + 1
  local cz, cx0, cy0 = cam_zoom, cam_x, cam_y
  local halfW, halfH = W/2, H/2
  local inv_cz = 1 / cz

  local prev_sx, prev_sy
  for sx = 0, W do
    -- 화면 x → 월드 x
    local wx = cx0 + (sx - halfW) * inv_cz
    -- 월드 y(표면) → 화면 y
    local wy = terrain_y_at(wx)
    local sy = math.floor(halfH + (wy - cy0) * cz)

    -- 표면 아래를 검정으로 채움 (지형 내부)
    if sy < bot then
      rectfill(sx, math.max(sy,0), sx, bot, BG)
    end
    -- 표면 윤곽선 (이전 열과 연결)
    if prev_sx then
      line(prev_sx, prev_sy, sx, sy, FG)
    end
    prev_sx, prev_sy = sx, sy
  end
end

-- ─── 착륙 패드 ────────────────────────────────────────────────
function draw_pads()
  for rep = -1, 1 do
    local offset_x = rep * WORLD_W
    for _,pad in ipairs(pads) do
      local wx  = pad.x + offset_x
      local wx2 = pad.x + pad.w + offset_x
      local sx  = math.floor(W/2 + (wx  - cam_x) * cam_zoom)
      local sx2 = math.floor(W/2 + (wx2 - cam_x) * cam_zoom)
      local sy  = math.floor(H/2 + (pad.y - cam_y) * cam_zoom)
      if sx2 >= 0 and sx <= W then
        -- 착륙 지점 표시: 지형 3px 아래에 점선
        local dy = sy + 3
        local dot_step = math.max(3, math.floor(5 * cam_zoom))
        local lx = sx
        while lx <= sx2 do
          pset(lx, dy, FG)
          lx = lx + dot_step
        end

        -- 배수 표시 (점선 아래)
        local mx = math.floor((sx+sx2)/2)
        local label = "x"..pad.mult
        local lw = #label * 4
        print(label, mx - lw//2, dy + 4, FG)
      end
    end
  end
end

-- ─── HUD ──────────────────────────────────────────────────────
function draw_hud()
  local l=lander
  local ty=terrain_y_at(l.x)
  local alt=math.max(0,math.floor(ty-l.y))
  local spd=math.sqrt(l.vx^2+l.vy^2)

  rectfill(0,0,W,18,BG); line(0,18,W,18,FG)

  -- 각도를 -180~180 범위로 정규화해서 표시
  local disp_ang = l.ang % 360
  if disp_ang > 180 then disp_ang = disp_ang - 360 end
  print("ALT:"..alt,                               8,  5,FG)
  print(string.format("SPD:%.1f",spd),             90, 5,FG)
  print("ANG:"..math.floor(disp_ang).."d",        175, 5,FG)
  print("SCORE:"..score,                          265,  5,FG)
  print("HI:"..high_score,                        360,  5,FG)
  print("LV:"..level,                             445,  5,FG)

  -- 연료 바: "FUEL" 글자 오른쪽에 게이지
  print("FUEL", 2, 22, FG)
  local gx = 24                       -- 게이지 시작 x (FUEL 글자 뒤)
  local gw = 110                      -- 게이지 전체 폭
  local fw = math.floor((l.fuel/FUEL_MAX)*gw)
  rect(gx, 22, gx+gw, 28, FG)
  if fw > 0 then rectfill(gx+1, 23, gx+fw, 27, FG) end
end

-- ─── 별 그리기 ────────────────────────────────────────────────
function draw_stars()
  local star_cam = (star_scroll or 0) * STAR_PARALLAX
  -- 줌에 약하게 반응 (지형보다 약하게): 가로·세로 동일 비율
  local sz = 1 + (cam_zoom - 1) * STAR_ZOOM_K
  for _,s in ipairs(stars_list) do
    -- parallax 스크롤된 화면 x
    local bx = (s.wx - star_cam) % W
    -- 화면 중심(W/2, H/2) 기준으로 가로·세로 같은 배율로 스케일
    local sx = math.floor(W/2 + (bx   - W/2) * sz)
    local sy = math.floor(H/2 + (s.y  - H/2) * sz)
    if sx < 0 or sx > W or sy < 0 or sy > H then
      -- 화면 밖이면 스킵
    elseif s.cross then
      pset(sx,   sy,   FG)
      pset(sx-1, sy,   FG)
      pset(sx+1, sy,   FG)
      pset(sx,   sy-1, FG)
      pset(sx,   sy+1, FG)
    else
      pset(sx, sy, FG)
    end
  end
end

-- ─── 파티클 ──────────────────────────────────────────────────
function draw_particles()
  for _,p in ipairs(particles_list) do
    local sx,sy=world_to_screen(p.x,p.y)
    local sz=math.max(1,math.floor(p.sz*cam_zoom))
    if sz>=2 then rectfill(sx-1,sy-1,sx+1,sy+1,p.col)
    else pset(sx,sy,p.col) end
  end
end

-- 먼지: 수명에 따라 원 → 점으로 줄어듦
-- want_front=true면 폭발 파편(지형 앞), false면 일반 먼지(지형 뒤)
function draw_dust(want_front)
  for _,p in ipairs(dust_list) do
    if (p.front or false) == (want_front or false) then
      local sx,sy=world_to_screen(p.x,p.y)
      local frac = p.life / p.max_life
      local rad  = math.floor(p.r0 * frac * cam_zoom)
      if rad >= 1 then
        circfill(sx, sy, rad, BG)
        circ(sx, sy, rad, FG)
      else
        pset(sx, sy, FG)
      end
    end
  end
end

-- ─── 충돌 판정 ────────────────────────────────────────────────
function foot_world(l, px, py)
  local r  = deg2rad(l.ang)
  local cs = math.cos(r)
  local sn = math.sin(r)
  return l.x + cs*px - sn*py,
         l.y + sn*px + cs*py
end

-- 특정 월드 x에서 지형의 경사 각도(도, 절대값) 반환
function terrain_slope_deg(wx)
  local d = 5
  local y1 = terrain_y_at(wx - d)
  local y2 = terrain_y_at(wx + d)
  return math.abs(math.atan((y2 - y1) / (d*2)) * 180 / math.pi)
end

function check_collision()
  local l = lander

  -- ① 발끝 판정 (tolerance: 발끝이 지형 3px 이내로 접근하면 닿은 것으로)
  local FOOT_TOL = 3
  local lfx, lfy = foot_world(l, -LANDER_FOOT_X, LANDER_FOOT_Y)
  local rfx, rfy = foot_world(l,  LANDER_FOOT_X, LANDER_FOOT_Y)
  local l_touch = lfy >= terrain_y_at(lfx) - FOOT_TOL
  local r_touch = rfy >= terrain_y_at(rfx) - FOOT_TOL

  -- ② 몸통 box 관통 판정 (발 제외 몸통 box가 지형에 닿으면 폭발)
  -- box 하단 변을 따라 여러 점을 샘플링해서 지형보다 아래면 관통
  local body_hit = false
  for i = 0, 4 do
    local px = BODY_BOX_L + (BODY_BOX_R - BODY_BOX_L) * (i/4)
    -- box 하단 모서리 점
    local bx, by = foot_world(l, px, BODY_BOX_B)
    if by >= terrain_y_at(bx) then
      body_hit = true
      break
    end
  end
  -- box 좌우 측면 하단 코너도 체크
  if not body_hit then
    for _, cx in ipairs({BODY_BOX_L, BODY_BOX_R}) do
      local bx, by = foot_world(l, cx, BODY_BOX_B)
      if by >= terrain_y_at(bx) then body_hit = true; break end
    end
  end

  if body_hit then
    return "body_hit", nil, false, false
  end

  if not l_touch and not r_touch then
    return "none", nil, false, false
  end

  for _,pad in ipairs(pads) do
    if l.x > pad.x and l.x < pad.x+pad.w then
      return "pad", pad, l_touch, r_touch
    end
  end
  return "ground", nil, l_touch, r_touch
end

-- ─── 레벨 / 게임 관리 ─────────────────────────────────────────
function start_level(lvl)
  level=lvl
  terrain_pts,pads=gen_terrain(lvl)
  trail_list={}; particles_list={}; dust_list={}; msg_timer=0
  shake_t=0
  csm=nil

  -- 게임 시작 초반과 동일하게: 오른쪽으로 비행하던 속도/각도로 시작
  local sx = WORLD_W/2
  local gy = terrain_y_at(sx)
  lander = new_lander()
  lander.x  = sx
  lander.y  = gy - 270            -- 고도 상향(약 1.8배)
  lander.vx = TITLE_SCROLL * 0.7 * 1.3   -- 비행 속도 1.3배
  lander.vy = 0
  lander.ang = 90                   -- 옆으로 비행하는 자세
  lander.alive = true
  lander.settling = false

  cam_x=lander.x; cam_y=lander.y; cam_zoom=1.0
  game_state="play"
end

-- 인트로: 사령선과 도킹한 채 오른쪽으로 비행 → 1초 후 분리
function start_intro()
  -- 타이틀에서 흐르던 지형/카메라를 그대로 이어받음
  -- 착륙선을 현재 화면 중앙 상공에 배치하고 비행 속도를 부여
  trail_list={}; particles_list={}; dust_list={}; msg_timer=0
  shake_t=0
  intro_t = 0

  -- 화면 중앙(cam_x) 위치, 지형보다 충분히 높은 곳에서 수평 비행
  local sx = cam_x
  local gy = terrain_y_at(sx)
  lander = new_lander()
  lander.x  = sx
  lander.y  = gy - 270           -- 고도 상향(약 1.8배)
  lander.vx = TITLE_SCROLL * 1.3 -- 비행 속도 1.3배
  lander.vy = 0
  lander.ang = 90             -- 진행 방향(오른쪽)으로 기수를 눕힘
  lander.alive = true
  lander.settling = false

  -- 도킹 장면이 또렷하게 보이도록 줌 인 상태로 시작
  cam_zoom = 1.4
  cam_y = lander.y

  -- 사령선(CSM): 착륙선 바로 앞(오른쪽)에 도킹, 세로 중앙 정렬
  csm = { x = sx + 32, y = lander.y, vx = TITLE_SCROLL * 1.3,
          attached = true, dock_dx = 32, dock_dy = 0 }

  game_state = "intro"
end

function update_intro()
  intro_t = intro_t + 1
  local l = lander

  if csm and csm.attached then
    -- 도킹 상태: 함께 수평 비행 (사령선은 착륙선 앞쪽 오프셋 유지)
    l.x = l.x + l.vx
    l.y = l.y + l.vy
    csm.x = l.x + csm.dock_dx
    csm.y = l.y + csm.dock_dy
    csm.vx = l.vx
  end

  -- 1초 후 분리
  if csm and csm.attached and intro_t >= INTRO_FRAMES then
    csm.attached = false
    csm.vx = TITLE_SCROLL * 1.3 * 1.15   -- 사령선은 계속 더 빠르게 전진
    l.vx = TITLE_SCROLL * 1.3 * 0.7      -- 착륙선은 속도 살짝 감소
    -- 각도는 도킹 시 자세(90도) 그대로 유지 — 플레이어가 직접 세움
    game_state = "play"
  end

  update_camera()
end

function _init()
  math.randomseed(math.floor(time()*1000)%2147483621)
  stars_list=gen_stars()
  score=0; high_score=0; level=1; flame_t=0
  trail_list={}; particles_list={}; dust_list={}; msg_timer=0
  shake_t=0
  csm=nil
  star_scroll=0
  game_state="title"
  terrain_pts,pads=gen_terrain(1)
  lander=new_lander()
  -- 타이틀 카메라: 지형을 화면 아래쪽에 두어 로고와 덜 겹치게
  cam_x = WORLD_W/2
  -- cam_y가 화면중심(H/2)에 매핑됨. 지형 표면을 화면 하단(약 75%)에 두려면
  -- 표면보다 위쪽(작은 y)에 카메라를 둔다.
  cam_zoom = 0.7
  cam_y = terrain_y_at(cam_x) - (H*0.25)/cam_zoom
end

-- ─── _update ──────────────────────────────────────────────────
function _update()
  flame_t=flame_t+1
  if shake_t and shake_t>0 then shake_t=shake_t-1 end
  -- Shift 누를 때마다 디버그 표시 토글
  if keyp("shift") then DEBUG_MODE = not DEBUG_MODE end

  for i=#particles_list,1,-1 do
    local p=particles_list[i]
    p.x=p.x+p.vx; p.y=p.y+p.vy; p.vy=p.vy+0.02; p.life=p.life-1
    if p.life<=0 then table.remove(particles_list,i) end
  end
  -- 먼지/파편: 마찰로 감속, 개별 중력(grav) 적용
  for i=#dust_list,1,-1 do
    local p=dust_list[i]
    p.x=p.x+p.vx; p.y=p.y+p.vy
    -- 중력이 클수록(폭발 파편) 마찰을 약하게 해서 더 멀리 흩어짐
    local fric = (p.grav > 0.02) and 0.985 or 0.92
    p.vx=p.vx*fric; p.vy=p.vy*fric + p.grav
    p.life=p.life-1
    if p.life<=0 then table.remove(dust_list,i) end
  end
  for i=#trail_list,1,-1 do
    trail_list[i].life=trail_list[i].life-1
    if trail_list[i].life<=0 then table.remove(trail_list,i) end
  end

  -- 분리된 사령선은 계속 전진 (도킹 중엔 update_intro가 갱신)
  if csm and not csm.attached then
    csm.x = csm.x + csm.vx
    -- 화면 오른쪽으로 충분히 멀어지면 제거
    local csx = world_to_screen(csm.x, csm.y)
    if csx > W + 60 then csm = nil end
  end

  if game_state=="title" then
    -- 지형을 왼쪽으로 흘려보냄(보이지 않는 비행체가 오른쪽으로 가는 것처럼)
    cam_x = (cam_x + TITLE_SCROLL) % WORLD_W
    star_scroll = (star_scroll or 0) + TITLE_SCROLL
    if btnp(4) or btnp(5) then
      score=0; level=1
      start_intro()
    end
    return
  end

  if game_state=="intro" then
    update_intro()
    return
  end

  if game_state=="crashed" then
    msg_timer=msg_timer-1
    if msg_timer<=0 and (btnp(4) or btnp(5)) then
      start_level(level)
    end
    update_camera(); return
  end

  if game_state=="landed" or game_state=="win" then
    -- 자동 진행 대신 Z키 대기 (메시지 표시 후 잠깐 입력 잠금)
    msg_timer=msg_timer-1
    if msg_timer<=0 and (btnp(4) or btnp(5)) then
      if game_state=="landed" then
        start_level(level+1)
      else
        game_state="title"; terrain_pts,pads=gen_terrain(1); lander=new_lander()
      end
    end
    update_camera(); return
  end

  local l=lander
  if not l.alive then update_camera(); return end

  -- ── 조작 (settling 중이면 회전·추력 모두 차단) ──────────────
  if not l.settling then
    if btn(0) then l.ang=l.ang-ROT_SPD end
    if btn(1) then l.ang=l.ang+ROT_SPD end
    l.ang=l.ang%360
    if btn(2) and l.fuel>0 then
      local r=deg2rad(l.ang)
      l.vx=l.vx+math.sin(r)*THRUST; l.vy=l.vy-math.cos(r)*THRUST
      l.fuel=l.fuel-1
      thrust_dust(l)   -- 저고도에서 지면 먼지
    end
  end

  -- ── settling 중: 물리 대신 강제 정착 처리 ──────────────────
  if l.settling then
    l.settle_t = l.settle_t + 1
    -- 중력만 살짝 적용 (천천히 가라앉음)
    l.vy = l.vy + GRAVITY * 0.5
    l.vx = l.vx * 0.6
    l.x  = l.x + l.vx
    l.y  = l.y + l.vy

    -- 지형 경사에 맞춰 자세를 천천히 회전 (중력에 의해 눕는 느낌)
    local gl = terrain_y_at(l.x - LANDER_FOOT_X)
    local gr = terrain_y_at(l.x + LANDER_FOOT_X)
    -- 오른쪽이 낮으면(gr 큼) 오른쪽으로 기울어야 함 → 양의 각도
    -- atan(높이차 / 밑변) 을 도(degree)로
    local target_ang = math.atan((gr - gl) / (LANDER_FOOT_X * 2)) * 180 / math.pi
    local cur = l.ang
    if cur > 180 then cur = cur - 360 end
    l.ang = (cur + (target_ang - cur) * 0.15) % 360

    update_camera()

    -- 발끝 침투량 계산 후 위로 보정
    local lfx,lfy = foot_world(l, -LANDER_FOOT_X, LANDER_FOOT_Y)
    local rfx,rfy = foot_world(l,  LANDER_FOOT_X, LANDER_FOOT_Y)
    local push = math.max(lfy-terrain_y_at(lfx), rfy-terrain_y_at(rfx), 0)
    if push > 0 then
      l.y  = l.y - push
      l.vy = 0
    end

    -- 일정 프레임 후 착륙 확정 (확실하게)
    if l.settle_t > 30 then
      l.alive=false; l.vx=0; l.vy=0
      -- 발끝을 지형에 딱 붙임
      local lfx2,lfy2 = foot_world(l, -LANDER_FOOT_X, LANDER_FOOT_Y)
      local rfx2,rfy2 = foot_world(l,  LANDER_FOOT_X, LANDER_FOOT_Y)
      l.y = l.y - math.max(lfy2-terrain_y_at(lfx2), rfy2-terrain_y_at(rfx2), 0)
      landing_puff(l.x, l.y+10)

      -- ── 채점 ──────────────────────────────────────────────
      -- 기본 100 × 패드배율(x1~x3). 한 발만 들어가면 50%.
      -- 회전각 ±5도 이내 +50, 속도 충분히 느리면 +50.
      -- 한 발만 걸친 경우: 패드 중앙 근접도에 따라 +0~+100.
      local sc = scoring  -- 전역 테이블에 세부 항목 기록
      sc.base   = 0
      sc.mult   = l.pad_mult
      sc.foot   = "none"
      sc.ang_b  = 0
      sc.spd_b  = 0
      sc.ctr_b  = 0

      if l.score_both then
        sc.base = 100 * l.pad_mult
        sc.foot = "both"
      elseif l.score_one then
        sc.base = math.floor(100 * l.pad_mult * 0.5)
        sc.foot = "one"
        -- 중앙 근접 가산점: ±4px 이내 +100, 가장자리(패드 반폭)에서 +0
        local half = l.score_pad_half or 25
        local d = l.score_cdist or half
        if d <= 4 then
          sc.ctr_b = 100
        else
          local t = clamp((half - d) / (half - 4), 0, 1)
          sc.ctr_b = math.floor(100 * t)
        end
      else
        sc.foot = "ground"
      end

      if sc.foot == "ground" then
        -- 착륙 지점이 아닌 곳: 딱 +50점만
        sc.base  = 50
        sc.ang_b = 0
        sc.spd_b = 0
        sc.ctr_b = 0
      else
        if l.score_ang <= 5 then sc.ang_b = 50 end
        if l.score_spd <= SOFT_SPD then sc.spd_b = 50 end
      end

      sc.total = sc.base + sc.ang_b + sc.spd_b + sc.ctr_b
      score = score + sc.total
      if score > high_score then high_score = score end

      msg_timer = 90
      game_state = (level>=8) and "win" or "landed"
    end
    return
  end

  -- ── 일반 비행 물리 ────────────────────────────────────────
  l.vy=l.vy+GRAVITY; l.vx=l.vx*0.998; l.vy=l.vy*0.998
  l.x=l.x+l.vx; l.y=l.y+l.vy
  if l.x < 0       then l.x = l.x + WORLD_W end
  if l.x > WORLD_W then l.x = l.x - WORLD_W end
  if l.y<-600 then l.vy=math.max(l.vy,0.1) end

  update_camera()

  local result,pad,l_touch,r_touch = check_collision()

  -- 몸통 관통(뾰족한 지형) → 폭발
  if result == "body_hit" then
    explode(l); l.alive=false
    score = score - 100
    msg_timer=90; game_state="crashed"; return
  end

  -- 공중 → 아무것도 안 함
  if result == "none" then
    return
  end

  -- 발 하나라도 닿은 순간: 속도/각도 체크
  local ang = math.abs(l.ang) % 360
  if ang > 180 then ang = 360 - ang end

  if l.vy > SAFE_VY or math.abs(l.vx) > SAFE_VX or ang > SAFE_ANG then
    explode(l); l.alive=false
    score = score - 100
    msg_timer=90; game_state="crashed"; return
  end

  -- 먼저 닿는 발의 지형 경사 체크: 45도 이상이면 실패
  do
    local lfx, lfy = foot_world(l, -LANDER_FOOT_X, LANDER_FOOT_Y)
    local rfx, rfy = foot_world(l,  LANDER_FOOT_X, LANDER_FOOT_Y)
    -- 침투량이 큰 발이 먼저 닿은 발
    local l_pen = lfy - terrain_y_at(lfx)
    local r_pen = rfy - terrain_y_at(rfx)
    local contact_x = (l_pen >= r_pen) and lfx or rfx
    if terrain_slope_deg(contact_x) >= 45 then
      explode(l); l.alive=false
      score = score - 100
      msg_timer=90; game_state="crashed"; return
    end
  end

  -- 안전 → settling 시작 (이후 위 블록에서 강제 정착 처리)
  l.settling      = true
  l.settle_t      = 0
  l.landed_on_pad = (result == "pad")
  l.pad_mult      = pad and pad.mult or 1

  -- 채점용 정보 기록 (착륙 접촉 순간의 상태)
  -- 두 발이 모두 패드 범위 안에 있는지 판정
  local both_on_pad = false
  local one_on_pad  = false
  local center_dist = 999
  if result == "pad" and pad then
    local lfx = foot_world(l, -LANDER_FOOT_X, LANDER_FOOT_Y)
    local rfx = foot_world(l,  LANDER_FOOT_X, LANDER_FOOT_Y)
    local l_in = lfx > pad.x and lfx < pad.x+pad.w
    local r_in = rfx > pad.x and rfx < pad.x+pad.w
    both_on_pad = l_in and r_in
    one_on_pad  = l_in or r_in
    -- 착륙선 중심과 패드 중앙의 거리
    local pad_cx = pad.x + pad.w/2
    center_dist = math.abs(l.x - pad_cx)
    l.score_pad_half = pad.w/2
  end
  l.score_both = both_on_pad
  l.score_one  = one_on_pad and not both_on_pad
  l.score_cdist = center_dist
  -- 착륙 순간 각도(좌우 절대값)와 속도
  l.score_ang  = ang
  l.score_spd  = math.sqrt(l.vx*l.vx + l.vy*l.vy)

  l.vx = l.vx * 0.2
end

-- ─── _draw ────────────────────────────────────────────────────
FILLP_CHECKER_A = {0xAA,0x55,0xAA,0x55,0xAA,0x55,0xAA,0x55}  -- 타이틀 박스용으로만 유지

function _draw()
  cls(BG)

  -- 화면 진동: cam을 임시로 흔든 뒤 그리기 끝에 복원
  local shake_dx, shake_dy = 0, 0
  if shake_t and shake_t>0 then
    local mag = shake_t * 0.35
    shake_dx = (math.random()-0.5) * mag * 2
    shake_dy = (math.random()-0.5) * mag * 2
    cam_x = cam_x + shake_dx
    cam_y = cam_y + shake_dy
  end

  draw_stars()

  if game_state=="title" then
    draw_terrain(); draw_pads()

    -- 벡터 로고: LUNAR / LANDER 두 줄 (외곽선 + 입체)
    draw_logo("LUNAR",  W/2, 30, 6)
    draw_logo("LANDER", W/2, 84, 6)

    -- 안내 텍스트 박스
    local by1 = 160
    local function outline_print(s,x,y)
      print(s,x-1,y,BG); print(s,x+1,y,BG)
      print(s,x,y-1,BG); print(s,x,y+1,BG)
      print(s,x,y,FG)
    end
    -- 중앙 정렬 헬퍼
    local function cprint(s,y)
      local w = #s*4
      outline_print(s, math.floor((W-w)/2), y)
    end
    cprint("A Picotron Adventure  "..VERSION, by1)
    cprint("<> Rotate    ^ Thrust",           by1+16)
    cprint("Land on the lit pads!",           by1+28)

    -- [Z] TO START : 깜빡임
    if math.floor(flame_t/20)%2==0 then
      local s="[ Z ]  TO  START"
      local w=#s*4
      outline_print(s, math.floor((W-w)/2), by1+48)
    end

    if high_score>0 then
      cprint("BEST: "..high_score, by1+64)
    end

    -- 빌드 시각 (하단)
    local build_msg = "Updated: "..BUILD_TIME
    local bw = #build_msg * 4
    print(build_msg, math.floor((W-bw)/2), H-9, FG)
    return
  end

  draw_dust(false)         -- 일반 먼지 (지형보다 뒤)
  draw_terrain(); draw_pads()
  draw_dust(true)          -- 폭발 파편 (지형 앞)
  draw_particles()         -- 기타 파티클 (지형 앞)

  -- 사령선 (인트로 도킹 중이거나 분리 후 화면에 남아있는 동안)
  if csm then draw_csm(csm) end

  if lander.alive then
    if btn(2) and lander.fuel>0 and game_state=="play" then draw_flame(lander) end
    draw_lander(lander)
  elseif game_state=="landed" then
    draw_lander(lander)
  end

  -- 진동 복원 (이후 UI는 흔들리지 않게)
  cam_x = cam_x - shake_dx
  cam_y = cam_y - shake_dy

  draw_hud()

  local blink = (math.floor(flame_t/20)%2==0)
  if game_state=="landed" or game_state=="win" then
    local sc = scoring
    local boxw = 190
    local mx=math.floor(W/2-boxw/2); local my=64
    local valx = mx + boxw - 12

    -- 표시할 줄 목록을 먼저 구성 (높이 동적 계산)
    local rows = {}
    if sc.foot == "ground" then
      -- 착륙 지점이 아닌 곳: 단순 +50점
      rows[#rows+1] = {"Off pad landing", "+50"}
    else
      local full_base = 100 * sc.mult
      rows[#rows+1] = {"Base  x"..sc.mult, "+"..full_base}
      if sc.foot == "one" then
        rows[#rows+1] = {"One Foot", "-"..math.floor(full_base*0.5)}
        rows[#rows+1] = {"Center bonus", "+"..sc.ctr_b}
      end
      rows[#rows+1] = {"Angle <5d",    "+"..sc.ang_b}
      rows[#rows+1] = {"Soft landing", "+"..sc.spd_b}
    end

    -- 박스 높이: 제목 + 줄들 + 구분선 + 총점 + 넉넉한 [Z] 여백
    local line_h = 11
    local top_pad = 22
    local rows_h  = #rows * line_h
    local h = top_pad + rows_h + 8 + 12 + 24   -- 마지막 24 = [Z] 위아래 여백
    rectfill(mx,my,mx+boxw,my+h,BG); rect(mx,my,mx+boxw,my+h,FG)

    local title = (game_state=="win") and "MISSION COMPLETE!" or "SAFE LANDING!"
    print(title, mx+10, my+8, FG)

    local function row(label, val, y)
      print(label, mx+10, y, FG)
      local vw = #val * 4
      print(val, valx - vw, y, FG)
    end

    local y = my + top_pad
    for _,r in ipairs(rows) do
      row(r[1], r[2], y); y = y + line_h
    end
    line(mx+10, y+2, mx+boxw-10, y+2, FG); y = y + 8
    row("Total Score", "+"..sc.total, y); y = y + 16

    if blink then
      local nxt = (game_state=="win") and "[ Z ] Title" or "[ Z ] Next"
      local nw = #nxt*4
      print(nxt, mx+(boxw-nw)/2, y, FG)
    end
  elseif game_state=="crashed" then
    local boxw=140
    local mx=math.floor(W/2-boxw/2); local my=74
    rectfill(mx,my,mx+boxw,my+52,BG); rect(mx,my,mx+boxw,my+52,FG)
    print("CRASH!",      mx+10, my+8,  FG)
    print("SCORE  -100", mx+10, my+24, FG)
    if blink then print("[ Z ] Retry", mx+10, my+40, FG) end
  end

  if game_state=="play" and lander.alive and lander.y<20 then
    if math.floor(flame_t/10)%2==0 then print("^",lander.x-3,20,FG) end
  end

  -- 디버그 (항상 맨 마지막에 그려서 가려지지 않게)
  if DEBUG_MODE then
    if lander and lander.alive then draw_debug(lander) end
    local fps = stat(7) or 0
    local cpu = (stat(1) or 0) * 100
    local y0 = H - 30
    print("[DEBUG]",                              4, y0,    11)
    print(string.format("CPU: %d%%", math.floor(cpu+0.5)), 4, y0+10, 11)
    print(string.format("FPS: %d",   math.floor(fps+0.5)), 4, y0+20, 11)
  end
end
