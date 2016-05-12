﻿module dcv.tracking.opticalflow.pyramidflow;


import dcv.core.utils : emptySlice;
import dcv.core.image;
import dcv.imgproc.imgmanip : warp, resize;
import dcv.tracking.opticalflow.base;


class DensePyramidFlow : DenseOpticalFlow {

	private DenseOpticalFlow flowAlgorithm;
	private uint levelCount;

	this(DenseOpticalFlow flow, uint levels) 
	in {
		assert(flow !is null);
		assert(levels > 0);
	} body {
		flowAlgorithm = flow;
		levelCount = levels;
	}

	override Flow evaluate(inout Image f1, inout Image f2, 
		Flow prealloc = emptySlice!(3, float),bool usePrevious = false) 
	in {
		assert(prealloc.length!2 == 2);
		assert(!f1.empty && f1.size == f2.size && 
			f1.depth == f2.depth && 
			f1.depth == BitDepth.BD_8);
		if (usePrevious) {
			assert(prealloc.length!0 == f1.height &&
				prealloc.length!1 == f1.width);
		}
	} body {

		// allocate highest level
		float []currentBuffer = new float[f1.height*f1.width];
		float []nextBuffer = new float[f1.height*f1.width];

		ulong [2]size = [f1.height, f1.width];
		uint level = 0;

		// pyramid flow array - each item is double sized flow from the next
		ulong [2][] flowPyramid;
		flowPyramid.length = levelCount;
		flowPyramid[$-1] = size.dup;

		Flow flow;

		foreach_reverse (i; 0..(levelCount-1)) { 
			size[] /= 2; 
			if (size[0] < 1 || size[1] < 1)
				throw new Exception("Pyramid downsampling exceeded minimal image size");
			flowPyramid[i] = size.dup;
		}

		// allocate flow for each pyramid level
		if (usePrevious) {
			flow = prealloc.resize(flowPyramid[0][0], flowPyramid[0][1]);
		} else {
			flow = new float[flowPyramid[0][0]*flowPyramid[0][1]*2]
				.sliced(flowPyramid[0][0], flowPyramid[0][1], 2);
			flow[] = 0.0f;
		}

		Slice!(2, float*) current;
		Slice!(2, float*) next;

		auto h = f1.height;
		auto w = f1.width;

		auto f1s = f1.asType!float.sliced!float.reshape(h, w);
		auto f2s = f2.asType!float.sliced!float.reshape(h, w);

		// calculate pyramid flow
		foreach(i; 0..levelCount) {

			auto lh = flow.length!0;
			auto lw = flow.length!1;

			if (lh != h || lw != w) {
				current = f1s.resize(lh, lw);
				next = f2s.resize(lh, lw);
			} else {
				current = f1s;
				next = f2s;
			}

			// evaluate the flow algorithm
			flow = flowAlgorithm.evaluate(
				current.asImage(f1.format),
				next.asImage(f2.format),
				flow, true);

			if (i < levelCount-1) {
				flow = flow.resize(flowPyramid[i+1][0], flowPyramid[i+1][1]);
				flow[] *= 2.0f;
			}
		}

		return flow;
	}

}