#include <stdio.h>
#include <stdlib.h>
#include <zstd.h>

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <input.zst> <output>\n", argv[0]);
        return 1;
    }
    const char *inPath = argv[1];
    const char *outPath = argv[2];

    FILE *fin = fopen(inPath, "rb");
    if (!fin) {
        perror("Failed to open input file");
        return 1;
    }
    FILE *fout = fopen(outPath, "wb");
    if (!fout) {
        perror("Failed to open output file");
        fclose(fin);
        return 1;
    }

    size_t inBufSize = ZSTD_DStreamInSize();
    size_t outBufSize = ZSTD_DStreamOutSize();
    void *inBuf = malloc(inBufSize);
    void *outBuf = malloc(outBufSize);

    if (!inBuf || !outBuf) {
        fprintf(stderr, "Failed to allocate memory\n");
        if (inBuf) free(inBuf);
        if (outBuf) free(outBuf);
        fclose(fin); fclose(fout);
        return 1;
    }

    ZSTD_DStream *dstream = ZSTD_createDStream();
    if (!dstream) {
        fprintf(stderr, "Failed to create ZSTD_DStream\n");
        free(inBuf); free(outBuf);
        fclose(fin); fclose(fout);
        return 1;
    }

    size_t initResult = ZSTD_initDStream(dstream);
    if (ZSTD_isError(initResult)) {
        fprintf(stderr, "ZSTD_initDStream error: %s\n", ZSTD_getErrorName(initResult));
        ZSTD_freeDStream(dstream);
        free(inBuf); free(outBuf);
        fclose(fin); fclose(fout);
        return 1;
    }

    size_t readBytes = 0;
    while ((readBytes = fread(inBuf, 1, inBufSize, fin)) > 0) {
        ZSTD_inBuffer input = { inBuf, readBytes, 0 };
        while (input.pos < input.size) {
            ZSTD_outBuffer output = { outBuf, outBufSize, 0 };
            size_t ret = ZSTD_decompressStream(dstream, &output, &input);
            if (ZSTD_isError(ret)) {
                fprintf(stderr, "ZSTD_decompressStream error: %s\n", ZSTD_getErrorName(ret));
                ZSTD_freeDStream(dstream);
                free(inBuf); free(outBuf);
                fclose(fin); fclose(fout);
                return 1;
            }
            if (output.pos > 0) {
                fwrite(outBuf, 1, output.pos, fout);
            }
        }
    }

    ZSTD_freeDStream(dstream);
    free(inBuf);
    free(outBuf);
    fclose(fin);
    fclose(fout);
    return 0;
}
