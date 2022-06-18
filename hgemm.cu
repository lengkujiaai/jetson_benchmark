#include <unistd.h>
#include <iostream>
#include <stdlib.h>
#include <assert.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include "fp16_conversion.h"

using namespace std;

//------------------------------------------------------------run time----------------------------------------//
//如果需要运行10个小时，只需要把#define hours (xxx)改成#define hours (10)就可以了
#define hours (0.04)

#include <time.h>
typedef long time_t;
#define seconds (3600)
#define timeover (hours*seconds)
//------------------------------------------------------------run time----------------------------------------//

//-----------------------------------------------------------------csv----------------------------------------//
typedef struct record
{
    char id1[30];
    char id2[30];
    char id3[30];
    char id4[30];
    char id5[30];
    char id6[30];
}rec;
//---------------------------------------------------------------csv----------------------------------------//


const char* cublasGetErrorString(cublasStatus_t status)
{
    switch(status)
    {
        case CUBLAS_STATUS_SUCCESS: return "CUBLAS_STATUS_SUCCESS";
        case CUBLAS_STATUS_NOT_INITIALIZED: return "CUBLAS_STATUS_NOT_INITIALIZED";
        case CUBLAS_STATUS_ALLOC_FAILED: return "CUBLAS_STATUS_ALLOC_FAILED";
        case CUBLAS_STATUS_INVALID_VALUE: return "CUBLAS_STATUS_INVALID_VALUE"; 
        case CUBLAS_STATUS_ARCH_MISMATCH: return "CUBLAS_STATUS_ARCH_MISMATCH"; 
        case CUBLAS_STATUS_MAPPING_ERROR: return "CUBLAS_STATUS_MAPPING_ERROR";
        case CUBLAS_STATUS_EXECUTION_FAILED: return "CUBLAS_STATUS_EXECUTION_FAILED"; 
        case CUBLAS_STATUS_INTERNAL_ERROR: return "CUBLAS_STATUS_INTERNAL_ERROR"; 
    }
    return "unknown error";
}

inline
cudaError_t checkCuda(cudaError_t result)
{
  if (result != cudaSuccess) {
    fprintf(stderr, "CUDA Runtime Error: %s\n", cudaGetErrorString(result));
    assert(result == cudaSuccess);
  }
  return result;
}

inline
cublasStatus_t checkCublas(cublasStatus_t result)
{
  if (result != CUBLAS_STATUS_SUCCESS) {
    fprintf(stderr, "CUDA Runtime Error: %s\n", cublasGetErrorString(result));
    assert(result == CUBLAS_STATUS_SUCCESS);
  }
  return result;
}

// Fill the array A(nr_rows_A, nr_cols_A) with random numbers on CPU
void CPU_fill_rand(float *A, int nr_rows_A, int nr_cols_A) {
	int a=1;

    for(int i = 0; i < nr_rows_A * nr_cols_A; i++){
		A[i] = (float)rand()/(float)(RAND_MAX/a);
	}
}

int main(int argc, char ** argv){
     long count = 0;
     long run_time;
     long minutes=0;
     long times=1;//矩阵的倍数，真实大小为1024乘以times，对不同的设备，times的数值不同
     time_t time_begin,time_end;
     sscanf(argv[1], "%ld", &run_time);
     sscanf(argv[2], "%ld", &times);
     printf("----------------------------start-------------------------------\n");

    //-----------------------------------------------------------csv----------------------------------------//
    //统计，性能，耗时，数组大小，矩阵大小，运算次数，平均速度，十亿次/秒，每
    rec item[3]={
        //{"statistics,","performance,","Time,","size,","matrix size,","average,"}
        {"统计,","性能(GFlop/s),","耗时(s),","运算次数,","数组大小,","平均耗时,"}
    };

    //rec r[3]={
    //    {"0001,","zhaoge,","30,","98,","98,","98,"},
    //    {"0002,","fenghao,","24,","60,","98,","98,"}
    //};

    rec *p;   
    FILE *T0;

    T0=fopen("benchmark_record/benchmark_record2.csv","a");
    p = item;
    fwrite(p->id1,1,strlen(p->id1),T0);
    fwrite(p->id2,1,strlen(p->id2),T0);
    fwrite(p->id3,1,strlen(p->id3),T0);
    //fwrite(p->id4,1,strlen(p->id4),T0);
    //fwrite(p->id5,1,strlen(p->id5),T0);
    //fwrite(p->id6,1,strlen(p->id6),T0);
     fwrite("\r\n",1,3,T0);
    char printfloat16[10] = "float16,";
    char printfloat32[10] = "float32,";
    char performance[8];
    char costTime[7];
    //char average[9];

    //-----------------------------------------------------------csv----------------------------------------//


  //int min_m_k_n = 2;
  //int max_m_k_n = 4096*8;
  int max_m_k_n = 1024 * times;
  //int max_m_k_n = 1024 * 6;//nano上6或8都合适
  int repeats = 10;
  int verbose = 1;

  
  if(verbose) 
    cout << "运行的数组大小为： "  << max_m_k_n
	 //<< " 每次结果的运行次数: " << repeats
	 << endl;

  cublasStatus_t stat;
  cublasHandle_t handle;

  checkCublas(cublasCreate(&handle));

  //if(verbose) cout << "allocating device variables" << endl;
  if(verbose) cout << "正在分配设备变量" << endl;
  
  // Allocate 3 arrays on CPU
  
  float *h_A = (float *)malloc(max_m_k_n * max_m_k_n * sizeof(float));
  float *h_B = (float *)malloc(max_m_k_n * max_m_k_n * sizeof(float));
  float *h_C = (float *)malloc(max_m_k_n * max_m_k_n * sizeof(float));
  
  CPU_fill_rand(h_A, max_m_k_n, max_m_k_n);
  CPU_fill_rand(h_B, max_m_k_n, max_m_k_n);
  CPU_fill_rand(h_C, max_m_k_n, max_m_k_n);

    // Allocate 3 arrays on GPU
    float *d_A32, *d_B32, *d_C32;
    checkCuda(cudaMallocManaged(&d_A32, max_m_k_n * max_m_k_n * sizeof(float)));
    checkCuda(cudaMallocManaged(&d_B32, max_m_k_n * max_m_k_n * sizeof(float)));
    checkCuda(cudaMallocManaged(&d_C32, max_m_k_n * max_m_k_n * sizeof(float)));
    
    checkCuda(cudaMemcpy(d_A32,h_A,max_m_k_n * max_m_k_n * sizeof(float),cudaMemcpyHostToDevice));
    checkCuda(cudaMemcpy(d_B32,h_B,max_m_k_n * max_m_k_n * sizeof(float),cudaMemcpyHostToDevice));
    checkCuda(cudaMemcpy(d_C32,h_C,max_m_k_n * max_m_k_n * sizeof(float),cudaMemcpyHostToDevice));
    
    int lda, ldb, ldc, m, n, k;
    const float alf32 = 1.0f;
    const float bet32 = 0.0f;
    const float *alpha32 = &alf32;
    const float *beta32 = &bet32;
  
    
  	__half *d_A16, *d_B16, *d_C16;
    checkCuda(cudaMallocManaged(&d_A16, max_m_k_n * max_m_k_n * sizeof(__half)));
    checkCuda(cudaMallocManaged(&d_B16, max_m_k_n * max_m_k_n * sizeof(__half)));
    checkCuda(cudaMallocManaged(&d_C16, max_m_k_n * max_m_k_n * sizeof(__half)));
    
    for (int i = 0; i < max_m_k_n * max_m_k_n; i++) {
      d_A16[i] = approx_float_to_half(h_A[i]);
  	  d_B16[i] = approx_float_to_half(h_B[i]);
  	  d_C16[i] = approx_float_to_half(h_C[i]);
    }
    
    //int lda, ldb, ldc, m, n, k;
    const __half alf16 = approx_float_to_half(1.0);
    const __half bet16 = approx_float_to_half(0.0);
    const __half *alpha16 = &alf16;
    const __half *beta16 = &bet16;

  //-------------------------------------------------------------------------------------------------//  
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);

  int size = max_m_k_n;
  bool is32 = true;
 
  time(&time_begin);
  while(1){
	  if(is32 == true)  
          {
             printf("------------------------------float16---------------------------\n");
             is32 = false;
           }
	  else  
          {
            printf("-------------------------------float32--------------------------\n");
            is32 = true;
          }
	  //if(count == 4)
	  //	  break;
          time(&time_end);
	  count = time_end - time_begin;
          if(count > run_time)
                //break;
             { 
                //printf("count: %d\n",count);
                minutes = count/60;
                printf("设置的总运行时间(分钟): %ld\n",minutes);
                //printf("time time_end: %d\n",time_end);
                break;
            }
	  //count += 1;
    	  double sum = 0.0;
          double avg = 0.0;
    	  for(int rep = 0; rep < repeats; rep++){
      		cudaEventRecord(start, 0);
	  	m=n=k=size;
	  	lda = m;
	  	ldb = k;
	  	ldc = m;
	  	if(is32 == true)
        		stat = cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, m, n, k, alpha32, d_A32, lda, d_B32, ldb, beta32, d_C32, ldc); 
	  	else
			stat = cublasHgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, m, n, k, alpha16, d_A16, lda, d_B16, ldb, beta16, d_C16, ldc); 
      		cudaEventRecord(stop,0);
      		cudaEventSynchronize(stop);
      		if(stat != CUBLAS_STATUS_SUCCESS){
			cerr << "cublasSgemmBatched failed" << endl;
			exit(1);
      		}
      		assert(!cudaGetLastError());
      
      		float elapsed;
      		cudaEventElapsedTime(&elapsed, start, stop);
      		elapsed /= 1000.0f;
      		sum += elapsed;
    		}
	
        avg = 	sum/repeats;
	 if(is32 == true)
  		//cout << "float32; size " << size << " average: " << avg << " s "<< endl;
                {
                cout << "float32; 数组大小 " << size << " 平均速度: " << avg << " s "<< endl;
                minutes = run_time/60;
                printf("设置的总运行时间(分钟): %ld\n",minutes);
                minutes = count/60;
                printf("目前已运行时间(分钟): %ld\n",minutes);
                //printf("运行时间(秒): %ld\n",run_time);
		//printf("从开始到目前运行总时间(秒): %ld\n",count);
                 }
	 else
  		//cout << "float16; size " << size << " average: " << sum/repeats << " s "<< endl;
                {
                cout << "float16; 数组大小 " << size << " 平均速度: " << sum/repeats << " s "<< endl;
                //printf("运行时间(秒): %ld\n",run_time);
                 }
         //printf("----------------------------------------------------------------\n");

  //-----------------------added by shihailong-----------------------------//
   	float msecPerMatrixMul = sum/repeats;
   	double flopsPerMatrixMul = 2.0 * (double)size * (double)size * (double)size;
   //double flopsPerMatrixMul = 2.0 * (double)max_m_k_n * (double)max_m_k_n * (double)max_m_k_n;
   	double gigaFlops = (flopsPerMatrixMul * 1.0e-9f) / (msecPerMatrixMul);
        printf(
            //"Performance= %.2f GFlop/s, Time= %.3f msec, Size= %.0f Ops\n\n",
            "性能= %.2f GFlop/s, 耗时= %.3f s, 运算次数= %.0f Ops\n\n",
            gigaFlops,
            msecPerMatrixMul,
            flopsPerMatrixMul);

//-----------------------------csv--------------------------------------------------------------//
        //p = r;
        if(is32 == true)
             fwrite(printfloat32,1,10,T0);
        else
             fwrite(printfloat16,1,10,T0);

        //fwrite(&gigaFlops,8,1,T0);
        sprintf(performance,"%.2f,", gigaFlops);
        //fwrite(&performance,1,10,T0);
        fwrite(&performance,1,sizeof(performance),T0);
        //fwrite(p->id2,1,strlen(p->id2),T0);

         sprintf(costTime,"%.3f,", msecPerMatrixMul);
        fwrite(&costTime,1,sizeof(costTime),T0);
        //fwrite(p->id3,1,strlen(p->id3),T0);



        //fwrite(p->id4,1,strlen(p->id4),T0);
        //fwrite(p->id5,1,strlen(p->id5),T0);

        //sprintf(average,"%.5f,", avg);
        //fwrite(&average,1,sizeof(average),T0);
        //fwrite(p->id6,1,strlen(p->id6),T0);
        fwrite("\r\n",1,3,T0);
    //fclose(T0);
        
//-----------------------------csv--------------------------------------------------------------//
  }

fclose(T0);

  	cudaFree(d_A32);
  	cudaFree(d_B32);
  	cudaFree(d_C32);
  	cudaFree(d_A16);
  	cudaFree(d_B16);
  	cudaFree(d_C16);

  // Free CPU memory
  free(h_A);
  free(h_B);
  free(h_C);
      
  return 0;
}
