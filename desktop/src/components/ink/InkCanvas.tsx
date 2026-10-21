import React, { useRef, useState, useEffect } from 'react';
import { PenTool, Highlighter, Eraser, Undo, Redo, Download } from 'lucide-react';

interface StrokePoint {
  x: number;
  y: number;
  p: number;
}

interface Stroke {
  id: string;
  tool: 'pen' | 'highlighter';
  color: string;
  width: number;
  points: StrokePoint[];
}

export const InkCanvas: React.FC = () => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [tool, setTool] = useState<'pen' | 'highlighter' | 'eraser'>('pen');
  const [color, setColor] = useState('#3B82F6');
  const [strokes, setStrokes] = useState<Stroke[]>([]);
  const [currentStroke, setCurrentStroke] = useState<Stroke | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Draw Grid Template (Goodnotes-style paper)
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.04)';
    ctx.lineWidth = 1;

    for (let x = 0; x < canvas.width; x += 30) {
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x, canvas.height);
      ctx.stroke();
    }
    for (let y = 0; y < canvas.height; y += 30) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(canvas.width, y);
      ctx.stroke();
    }

    // Render Strokes
    for (const stroke of strokes) {
      if (stroke.points.length < 2) continue;
      ctx.beginPath();
      ctx.strokeStyle = stroke.color;
      ctx.lineWidth = stroke.width;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.globalAlpha = stroke.tool === 'highlighter' ? 0.35 : 1.0;

      ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
      for (let i = 1; i < stroke.points.length; i++) {
        ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
      }
      ctx.stroke();
    }
    ctx.globalAlpha = 1.0;
  }, [strokes]);

  const handlePointerDown = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const pt: StrokePoint = {
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
      p: e.pressure || 0.5,
    };

    if (tool === 'eraser') {
      // Simple distance-based stroke eraser
      setStrokes(
        strokes.filter((s) => !s.points.some((p) => Math.hypot(p.x - pt.x, p.y - pt.y) < 15))
      );
      return;
    }

    const newStroke: Stroke = {
      id: `stroke-${Date.now()}`,
      tool: tool as 'pen' | 'highlighter',
      color,
      width: tool === 'highlighter' ? 14 : 3,
      points: [pt],
    };
    setCurrentStroke(newStroke);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLCanvasElement>) => {
    if (!currentStroke) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const pt: StrokePoint = {
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
      p: e.pressure || 0.5,
    };

    const updated = {
      ...currentStroke,
      points: [...currentStroke.points, pt],
    };
    setCurrentStroke(updated);

    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const pts = updated.points;
    if (pts.length >= 2) {
      ctx.beginPath();
      ctx.strokeStyle = updated.color;
      ctx.lineWidth = updated.width;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.globalAlpha = updated.tool === 'highlighter' ? 0.35 : 1.0;
      ctx.moveTo(pts[pts.length - 2].x, pts[pts.length - 2].y);
      ctx.lineTo(pt.x, pt.y);
      ctx.stroke();
      ctx.globalAlpha = 1.0;
    }
  };

  const handlePointerUp = () => {
    if (currentStroke) {
      setStrokes([...strokes, currentStroke]);
      setCurrentStroke(null);
    }
  };

  return (
    <div className="flex-1 flex flex-col items-center p-6 bg-[#0B0D13] overflow-auto select-none">
      {/* Floating Stylus Palette */}
      <div className="flex items-center gap-2 p-1.5 rounded-full bg-[#161923] border border-white/[0.12] shadow-2xl mb-4 text-xs">
        <button
          onClick={() => setTool('pen')}
          className={`p-2 rounded-full transition ${tool === 'pen' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'}`}
          title="Ballpoint Pen"
        >
          <PenTool className="w-4 h-4" />
        </button>

        <button
          onClick={() => setTool('highlighter')}
          className={`p-2 rounded-full transition ${tool === 'highlighter' ? 'bg-amber-500 text-white' : 'text-slate-400 hover:text-white'}`}
          title="Highlighter"
        >
          <Highlighter className="w-4 h-4" />
        </button>

        <button
          onClick={() => setTool('eraser')}
          className={`p-2 rounded-full transition ${tool === 'eraser' ? 'bg-red-500 text-white' : 'text-slate-400 hover:text-white'}`}
          title="Stroke Eraser"
        >
          <Eraser className="w-4 h-4" />
        </button>

        <div className="w-[1px] h-4 bg-white/[0.1] mx-1" />

        {['#3B82F6', '#8B5CF6', '#10B981', '#F59E0B', '#EF4444', '#FFFFFF'].map((c) => (
          <button
            key={c}
            onClick={() => setColor(c)}
            style={{ backgroundColor: c }}
            className={`w-4 h-4 rounded-full transition ${color === c ? 'ring-2 ring-white scale-110' : 'opacity-70 hover:opacity-100'}`}
          />
        ))}

        <div className="w-[1px] h-4 bg-white/[0.1] mx-1" />

        <button
          onClick={() => setStrokes(strokes.slice(0, -1))}
          className="p-2 rounded-full text-slate-400 hover:text-white transition"
          title="Undo Stroke"
        >
          <Undo className="w-4 h-4" />
        </button>
      </div>

      {/* A4 Paper Viewport */}
      <div className="relative shadow-2xl rounded-sm bg-[#12151F] border border-white/[0.08] overflow-hidden">
        <canvas
          ref={canvasRef}
          width={794}
          height={1123}
          onPointerDown={handlePointerDown}
          onPointerMove={handlePointerMove}
          onPointerUp={handlePointerUp}
          className="touch-none cursor-crosshair"
        />
      </div>
    </div>
  );
};
