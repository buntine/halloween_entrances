#!/usr/bin/env ruby

require 'curses'
require 'json'

include Curses

themes = JSON.parse(File.read(File.expand_path("themes.json")))["themes"]

MAX_INDEX = themes.length - 1
MIN_INDEX = 0
VIEWPORT_SIZE = 20
SONG_LENGTH = 65

@index = 0

init_screen
start_color

curs_set(0)
noecho

init_pair(1, COLOR_BLACK, COLOR_CYAN)
init_pair(2, COLOR_WHITE, COLOR_BLUE)
init_pair(3, COLOR_GREEN, COLOR_BLACK)

win = Curses::Window.new(0, 0, 1, 2)
win.keypad = true
win.scrollok(true)

viewport_start = 0
viewport_end = VIEWPORT_SIZE - 1

loop do
  win.setpos(0,0)

  win.attron(color_pair(3)) do
    clrtoeol
    win << "WRESTLING ENTRANCE MUSIC OF DOOM"
    win << "\n\n"
    win << "  1. Select your wrestler"
    win << "\n"
    win << "  2. Press ENTER"
    win << "\n\n"
  end

  themes[viewport_start..viewport_end].each.with_index(0) do |theme, index|
    if (index + viewport_start) == @index
      win.attron(color_pair(1)) { win << theme["name"] }
    else
      win << theme["name"]
    end
    clrtoeol
    win << "\n"
  end
  (win.maxy - win.cury).times {win.deleteln()}
  win.refresh

  choice = win.getch.to_s

  case choice
  when '258' # Down
    @index = @index >= MAX_INDEX ? MAX_INDEX : @index + 1

    if @index > viewport_end
      if viewport_end < MAX_INDEX
        viewport_end += 1
        viewport_start += 1
      end
    end
  when '259' # UP
    @index = @index <= MIN_INDEX ? MIN_INDEX : @index - 1

    if @index < viewport_start
      if viewport_start > MIN_INDEX
        viewport_end -= 1
        viewport_start -= 1
      end
    end
  when '10'
    @selected = themes[@index]

    win.clear
    win.refresh

    subwin = win.subwin(0, 0, 1, 2)
    subwin.setpos(0, 0)
    subwin.color_set(2)

    5.downto(1).each do |secs|
      subwin.clear
      subwin.attron(color_pair(3)) do
        subwin << "\nPLAYING #{@selected["name"]} in #{secs} seconds!"
      end
      subwin.refresh
      sleep(1)
    end

    a_pid = spawn("mpg123 -q data/#{@selected["audio"]}")
    Process.detach(a_pid)

    _, v_w = IO.pipe
    v_pid = Process.spawn("vlc --fullscreen --play-and-exit --no-audio --verbose 0 --no-osd --video-on-top --no-video-title-show data/#{@selected["video"]}", out: v_w, err: [:child, :out])
    v_w.close
    Process.detach(v_pid)

    SONG_LENGTH.downto(1).each do |secs|
      progress = ("*" * (SONG_LENGTH - secs)).ljust(SONG_LENGTH, " ")

      subwin.clear
      subwin.attron(color_pair(3)) do
        subwin << "\nPLAYING #{@selected["name"]}"
        subwin << "\n\n"
      end
      subwin.attron(color_pair(1)) do
        subwin << "[" + progress + "]"
      end
      subwin.refresh
      sleep(1)
    end

    subwin.close
  when 'q'
    exit 0
  end
end
