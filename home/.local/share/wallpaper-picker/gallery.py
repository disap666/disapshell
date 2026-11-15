#!/usr/bin/python
import fcntl
import math
from pathlib import Path
import random
import runpy
import threading
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, GtkLayerShell
import cairo

base = Path.home() / '.local/share/wallpaper-picker'
backend = runpy.run_path(str(base / 'backend.py'))
lock = open(Path.home() / '.cache/wallpaper-picker/gallery.lock', 'w')
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit(0)

class Gallery(Gtk.Window):
    def __init__(self):
        super().__init__(title='Обои')
        self.paths = backend['files']()
        if not self.paths:
            backend['notify']('Добавь изображения или GIF в ~/wallpapers')
            raise SystemExit(0)
        current = backend['STATE'].read_text() if backend['STATE'].exists() else ''
        self.selected = next((i for i,p in enumerate(self.paths) if str(p)==current),0)
        self.position = float(self.selected)
        self.busy = False
        self.error = ''
        self.timer = None
        self.hits = []
        self.pictures = {}
        for i,path in enumerate(self.paths):
            try:
                self.pictures[i] = GdkPixbuf.Pixbuf.new_from_file(str(backend['thumbnail'](path)))
            except Exception:
                pass
        self.set_app_paintable(True)
        self.set_visual(self.get_screen().get_rgba_visual())
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, 'wallpaper-carousel')
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (GtkLayerShell.Edge.TOP,GtkLayerShell.Edge.BOTTOM,GtkLayerShell.Edge.LEFT,GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self,edge,True)
        self.area=Gtk.DrawingArea()
        self.add(self.area)
        self.area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK|Gdk.EventMask.SCROLL_MASK|Gdk.EventMask.SMOOTH_SCROLL_MASK)
        self.area.connect('draw',self.draw)
        self.area.connect('button-press-event',self.click)
        self.area.connect('scroll-event',self.scroll)
        self.connect('key-press-event',self.key)
        self.connect('destroy',Gtk.main_quit)
        self.show_all()

    def move(self,step):
        if self.busy:return
        self.selected=max(0,min(len(self.paths)-1,self.selected+step))
        if self.timer is None:self.timer=GLib.timeout_add(16,self.animate)

    def animate(self):
        self.position+=(self.selected-self.position)*.21
        done=abs(self.selected-self.position)<.003
        if done:self.position=float(self.selected);self.timer=None
        self.area.queue_draw()
        return not done

    def rounded(self,c,x,y,w,h,r=16):
        c.new_sub_path()
        for cx,cy,start in [(x+w-r,y+r,-90),(x+w-r,y+h-r,0),(x+r,y+h-r,90),(x+r,y+r,180)]:
            c.arc(cx,cy,r,math.radians(start),math.radians(start+90))
        c.close_path()

    def text(self,c,text,x,y,size=13,color=(.81,.84,.93)):
        c.select_font_face('JetBrains Mono',cairo.FONT_SLANT_NORMAL,cairo.FONT_WEIGHT_NORMAL)
        c.set_font_size(size)
        c.set_source_rgb(*color)
        c.move_to(x-c.text_extents(text).width/2,y)
        c.show_text(text)

    def draw(self,widget,c):
        w,h=widget.get_allocated_width(),widget.get_allocated_height()
        c.set_operator(cairo.OPERATOR_SOURCE);c.set_source_rgba(0,0,0,0);c.paint();c.set_operator(cairo.OPERATOR_OVER)
        # Landscape filmstrip floating above the desktop.
        self.hits=[]
        center=h*.46
        cardw=min(480,w*.34)
        spacing=cardw*.80
        visible=sorted(range(len(self.paths)),key=lambda i:abs(i-self.position),reverse=True)
        for i in visible:
            d=i-self.position
            if abs(d)>3.2:continue
            scale=max(.55,1-abs(d)*.16)
            cw=cardw*scale;ch=cw*9/16
            x=w/2+d*spacing-cw/2
            y=center-ch/2+min(abs(d),3)*15
            if x>w or x+cw<0:continue
            alpha=max(.36,1-abs(d)*.20)
            # Soft, layered shadows keep each landscape card distinct.
            for spread in (18,12,6):
                self.rounded(c,x-spread/2,y+8-spread/2,cw+spread,ch+spread,18+spread/2)
                c.set_source_rgba(.015,.025,.035,.10*alpha);c.fill()
            c.save()
            self.rounded(c,x,y,cw,ch,16);c.clip()
            c.set_source_rgba(.08,.11,.13,.94);c.paint()
            pix=self.pictures.get(i)
            if pix:
                c.save()
                c.translate(x,y)
                factor=max(cw/pix.get_width(),ch/pix.get_height())
                c.translate((cw-pix.get_width()*factor)/2,(ch-pix.get_height()*factor)/2)
                c.scale(factor,factor)
                Gdk.cairo_set_source_pixbuf(c,pix,0,0);c.paint_with_alpha(alpha)
                c.restore()
            c.restore()
            self.rounded(c,x,y,cw,ch,16)
            c.set_source_rgba(.72,.88,.87,.95 if i==self.selected else .26)
            c.set_line_width(2 if i==self.selected else 1);c.stroke()
            self.hits.append((x,y,cw,ch,i))
        return False

    def choose(self):
        if self.busy:return
        self.busy=True;self.error='';self.area.queue_draw()
        path=self.paths[self.selected]
        def work():
            try:backend['apply'](path)
            except Exception as error:GLib.idle_add(self.failed,str(error))
            else:GLib.idle_add(self.destroy)
        threading.Thread(target=work,daemon=True).start()

    def failed(self,error):
        self.busy=False;self.error='Ошибка применения. Повтори Enter.'
        backend['notify'](str(error));self.area.queue_draw()
        return False

    def click(self,widget,event):
        if self.busy:return True
        for x,y,w,h,i in reversed(self.hits):
            if x<=event.x<=x+w and y<=event.y<=y+h:
                if i==self.selected:self.choose()
                else:self.move(i-self.selected)
                return True
        self.destroy()
        return True

    def scroll(self,widget,event):
        if event.direction in (Gdk.ScrollDirection.DOWN,Gdk.ScrollDirection.RIGHT):self.move(1)
        elif event.direction in (Gdk.ScrollDirection.UP,Gdk.ScrollDirection.LEFT):self.move(-1)
        elif event.direction==Gdk.ScrollDirection.SMOOTH:
            _,dx,dy=event.get_scroll_deltas()
            delta=dx if abs(dx)>abs(dy) else dy
            if abs(delta)>.3:self.move(1 if delta>0 else -1)
        return True

    def key(self,widget,event):
        if event.keyval==Gdk.KEY_Escape and not self.busy:self.destroy()
        elif event.keyval in (Gdk.KEY_Right,Gdk.KEY_l):self.move(1)
        elif event.keyval in (Gdk.KEY_Left,Gdk.KEY_h):self.move(-1)
        elif event.keyval in (Gdk.KEY_Return,Gdk.KEY_KP_Enter):self.choose()
        elif event.keyval in (Gdk.KEY_r,Gdk.KEY_R):self.move(random.randrange(len(self.paths))-self.selected)
        return True

if __name__ == '__main__':
    Gallery()
    Gtk.main()
